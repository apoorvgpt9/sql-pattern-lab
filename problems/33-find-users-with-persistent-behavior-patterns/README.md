# 33 · Find Users with Persistent Behavior Patterns

## 1. Problem & trigger phrases

Original: [Find Users with Persistent Behavior Patterns](https://leetcode.com/problems/find-users-with-persistent-behavior-patterns/) (LeetCode 3832, hard). Read the statement there; this guide only restates the spec in its own words.

**Spec (own words):** first throw away every (user, day) on which the user did more than one action. On what is left, a *streak* is a maximal run of consecutive calendar days on which the user did the same action. Report each user who has a streak of at least 5 days, with their single longest streak: user, action, length, first day, last day. Longest streaks first, then by user id.

| Trigger phrase | What it forces in SQL |
|---|---|
| "at least 5 consecutive days" | Gaps and islands on **calendar dates**. `DATE_SUB(action_date, INTERVAL ROW_NUMBER() … DAY)` is constant along a run of consecutive days. Never `action_date - ROW_NUMBER()`: MySQL turns the date into the number 20231231 and the label breaks at every month end. |
| "exactly one action per day" | A filter at (user, day) grain that runs **before** islands: `GROUP BY user_id, action_date HAVING COUNT(*) = 1`. The day is removed, not reduced to one action, so it also leaves a gap that breaks the streak. |
| "same on all those consecutive days" | The island key is (user, action), so `PARTITION BY user_id, action`. Partitioning by user alone lets a streak change action halfway. |
| "only consider the sequence with the maximum length" | A second grain change: from island to user. Rank islands per user and keep one (`ROW_NUMBER() … WHERE rn = 1`). The spec does not say which one wins a tie; see Assumptions. |

## 2. Schema & grain

| Table | One row means | Keys that matter here |
|---|---|---|
| `activity` | one action by one user on one day | PK (`user_id`, `action_date`, `action`): a user can have several actions on one day, but never the same action twice |

**Output grain:** one row per qualifying user. The row count is at most `SELECT COUNT(DISTINCT user_id) FROM activity`.

**Where the grain changes:** three times, and each change is a separate step.

1. (user, day, action) → **(user, day)**: decide which days are clean. This is a `GROUP BY` on a key that does *not* include the action, because the rule is about how many actions a day has.
2. (user, day) → **(user, action, streak)**: the islands. Rows collapse into one row per streak, with its length and its first and last days.
3. (user, action, streak) → **(user)**: keep only the longest streak.

The usual bug is doing step 2 on raw rows, skipping step 1. Partitioned by (user, action), a multi-action day still looks like an ordinary day of each of its actions, so the streak never breaks.

## Assumptions

Confidence in `problems.yaml` is `medium`. Each interpretation below is tested by a dataset.

1. **Two equally long longest streaks for one user: report the one that starts first** (earliest `start_date`). The spec leaves this open and the reference solution it was drawn from keeps an arbitrary one. A deterministic rule is required here because every approach must return the same answer. The earliest start is also the natural reading of "the first time this user built a streak that long". Tested by `tests/edge_tied_longest.sql`, where the earlier streak has the alphabetically *later* action, so a tie-break by action name gives a different answer (`mistakes/tie_break_by_action.sql`).
2. **Consecutive means consecutive calendar days**, so a day with no activity breaks a streak (`tests/edge_longest_per_user.sql`), and so does a removed multi-action day (`tests/edge_multi_action_day.sql`, `tests/edge_no_streak.sql`).
3. **`streak_length` is the number of days in the streak.** After the clean-day filter there is one row per (user, day), so `COUNT(*)` and `DATEDIFF(end_date, start_date) + 1` agree. "At least 5" therefore means 5 days, which is `DATEDIFF(...) >= 4` (`mistakes/strictly_more_than_5.sql` uses `>= 5` and fails).

## 3. Hint ladder

<details><summary>Hint 1</summary>

Pattern: **gaps and islands on dates, per partition**, followed by **top-1 per group**.

</details>

<details><summary>Hint 2</summary>

Shape: (1) keep only the (user, day) pairs that have a single action. (2) Within each (user, action), label runs of consecutive days. (3) Collapse each run to one row with its length and its first and last day, keeping runs of 5 or more. (4) Keep the longest run per user, with a stated tie rule. (5) Sort.

</details>

<details><summary>Hint 3</summary>

Key trick: `DATE_SUB(action_date, INTERVAL ROW_NUMBER() OVER (PARTITION BY user_id, action ORDER BY action_date) DAY)` is the same date for every day of one streak. A removed day leaves a hole in the dates, so the label jumps there without any extra logic. For step 1, `GROUP BY user_id, action_date HAVING COUNT(*) = 1` with `MIN(action)` recovers the one action without a join back.

</details>

## 4. Decomposition

The wording gives you three filters at three different grains. Put each one at the grain it talks about: "one action per day" is about days, "at least 5" is about streaks, and "maximum length" is about users.

1. **`clean`: `GROUP BY user_id, action_date HAVING COUNT(*) = 1`, `MIN(action)`.**
   *Why a GROUP BY here:* "exactly one action per day" counts actions per (user, day). That needs a group whose key leaves `action` out. `MIN(action)` is that single action, which `ONLY_FULL_GROUP_BY` accepts, so no join back to `activity` is needed. A window `COUNT(*) OVER (PARTITION BY user_id, action_date)` works too (approach 2).
2. **`labelled`: `island = action_date - rn days`, with `PARTITION BY user_id, action ORDER BY action_date`.**
   *Why a window here:* "consecutive" depends on each day's position among that user's days for that action, and only a window sees position. The partition includes `action` because the streak must keep one action.
3. **`streaks`: `GROUP BY user_id, action, island HAVING COUNT(*) >= 5`.**
   *Why a GROUP BY here:* the output describes a streak (length, start, end), so the grain becomes one row per island. "At least 5" is a test on the group, hence `HAVING`.
4. **`ranked`: `ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY streak_length DESC, start_date)`, keep `rn = 1`.**
   *Why a window and not `MAX`:* you need the whole row of the longest streak (its action and dates), not only its length. `GROUP BY user_id` + `MAX(streak_length)` gives the length, and getting the rest would need a join back that returns two rows on a tie. `start_date` in the `ORDER BY` is the tie rule from Assumptions.
5. **Final: `ORDER BY streak_length DESC, user_id`.** One row per user, so these two keys never tie.

```sql
WITH clean AS (                                -- step 1: (user, day, action) -> clean (user, day)
  SELECT user_id, action_date, MIN(action) AS action
  FROM activity
  GROUP BY user_id, action_date
  HAVING COUNT(*) = 1
),
labelled AS (                                  -- step 2: one label per run of consecutive days
  SELECT user_id, action, action_date,
         DATE_SUB(action_date, INTERVAL
                  ROW_NUMBER() OVER (PARTITION BY user_id, action ORDER BY action_date) DAY) AS island
  FROM clean
),
streaks AS (                                   -- step 3: island grain, keep >= 5 days
  SELECT user_id, action, COUNT(*) AS streak_length,
         MIN(action_date) AS start_date, MAX(action_date) AS end_date
  FROM labelled
  GROUP BY user_id, action, island
  HAVING COUNT(*) >= 5
),
ranked AS (                                    -- step 4: longest per user, earliest wins a tie
  SELECT user_id, action, streak_length, start_date, end_date,
         ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY streak_length DESC, start_date) AS rn
  FROM streaks
)
SELECT user_id, action, streak_length, start_date, end_date
FROM ranked
WHERE rn = 1
ORDER BY streak_length DESC, user_id;           -- step 5
```

Worked example of the label, from `tests/edge_multi_action_day.sql`, user 1, action `view`. The clean days are 04-01, 04-02, 04-04, 04-05, 04-06 (04-03 was removed), with row numbers 1–5. Subtracting gives 03-31, 03-31, 04-01, 04-01, 04-01. The removed day shifts every later label by one day, which splits the run into 2 days and 3 days.

## 5. Approaches: brute force → optimal

### Approach 1: streak ends with NOT EXISTS (`solutions/01_not_exists_streak_ends.sql`)

No window functions. The idea most people reach for first: a streak *starts* on a day whose previous day is missing, and *ends* on the first day after that whose next day is missing.

```sql
WITH clean AS (                       -- rows whose (user, day) has no other action
  SELECT a.* FROM activity a
  WHERE NOT EXISTS (SELECT 1 FROM activity o
                    WHERE o.user_id = a.user_id AND o.action_date = a.action_date
                      AND o.action <> a.action)
),
starts AS (                           -- no same-action clean day yesterday
  SELECT c.user_id, c.action, c.action_date AS start_date FROM clean c
  WHERE NOT EXISTS (SELECT 1 FROM clean p
                    WHERE p.user_id = c.user_id AND p.action = c.action
                      AND p.action_date = c.action_date - INTERVAL 1 DAY)
),
streaks AS (                          -- first day on/after the start whose next day is missing
  SELECT s.*, (SELECT MIN(e.action_date) FROM clean e
               WHERE e.user_id = s.user_id AND e.action = s.action
                 AND e.action_date >= s.start_date
                 AND NOT EXISTS (SELECT 1 FROM clean n
                                 WHERE n.user_id = e.user_id AND n.action = e.action
                                   AND n.action_date = e.action_date + INTERVAL 1 DAY)) AS end_date
  FROM starts s
),
long_streaks AS (
  SELECT *, DATEDIFF(end_date, start_date) + 1 AS streak_length
  FROM streaks WHERE DATEDIFF(end_date, start_date) + 1 >= 5
)
SELECT l.user_id, l.action, l.streak_length, l.start_date, l.end_date
FROM long_streaks l
WHERE NOT EXISTS (SELECT 1 FROM long_streaks b          -- no better streak for this user
                  WHERE b.user_id = l.user_id
                    AND (b.streak_length > l.streak_length
                         OR (b.streak_length = l.streak_length AND b.start_date < l.start_date)))
ORDER BY l.streak_length DESC, l.user_id;
```

**Why it is correct:** the end is the *first* day e ≥ start whose next day is missing. Every day from the start up to e must therefore be present, since otherwise an earlier day would have a missing successor. So [start, end] is exactly one maximal streak. The final `NOT EXISTS` keeps the streak that no other streak of the same user beats, which is the longest, with the earliest start on a tie.

**Cost model (reasoned from EXPLAIN):** every `NOT EXISTS` on an exact day is a primary-key lookup, which is cheap. The expensive part is the end-of-streak subquery. It runs once per start, and without `indexes.sql` it reads *all* of that user's rows (EXPLAIN: `Covering index lookup on a using PRIMARY (user_id=…)`), with a nested `NOT EXISTS` for each. That is roughly (streaks per user) × (rows per user) per user, so heavy users grow quadratically. `clean` is referenced four times and is re-evaluated as correlated probes against `activity` rather than computed once.

### Approach 2: LAG flag + running SUM (`solutions/02_lag_running_sum.sql`)

```sql
-- after clean days (window COUNT(*) per (user, day) = 1):
flagged AS (
  SELECT user_id, action, action_date,
         CASE WHEN LAG(action_date) OVER w = action_date - INTERVAL 1 DAY THEN 0 ELSE 1 END AS is_start
  FROM clean WINDOW w AS (PARTITION BY user_id, action ORDER BY action_date)
),
numbered AS (
  SELECT user_id, action, action_date,
         SUM(is_start) OVER (PARTITION BY user_id, action ORDER BY action_date
                             ROWS UNBOUNDED PRECEDING) AS streak_no
  FROM flagged
)
-- then the same GROUP BY streak / ROW_NUMBER per user as approach 3
```

**Why it is correct:** a day starts a new streak exactly when yesterday is not the previous clean day of the same action. The running count of starts is the same for every day of one streak and goes up by 1 at each new streak.

**Cost model (reasoned from EXPLAIN):** a window count per (user, day), then a sort for `LAG`, a second sort and pass for the running `SUM`, then the `GROUP BY` and the ranking. That is three window passes over the data and one materialised CTE per step, against approach 3's one window pass. Its advantage is flexibility. "Consecutive" can become any rule a `LAG` comparison can express, such as "gap of at most 2 days" or "same session".

### Approach 3 (optimal): date minus ROW_NUMBER (`solutions/03_date_minus_row_number.sql`)

The SQL is the assembled query in section 4.

**Why it is correct:** within one (user, action), sorted by date, `ROW_NUMBER()` goes up by 1 per row. Along consecutive days the date also goes up by 1, so `date - rn` is constant. Across a gap of g missing days the date goes up by g + 1 while `rn` goes up by 1, so the label jumps by g. One label per maximal streak, and `COUNT(*)` per label is the streak length.

**Cost model (reasoned from EXPLAIN):** the clean-day `GROUP BY` streams in primary-key order (EXPLAIN: `Group aggregate … Index scan on activity using PRIMARY`, no temporary table). Then one sort by (user, action, date) for `ROW_NUMBER()`, an aggregation into a temporary table for the islands, and a sort over the much smaller set of streaks for the ranking. So there is one full-size sort, against two in approach 2.

**Measured** (`gen.py` data, generated by the bench workflow; the table is filled in automatically, so never type numbers here):

<!-- BENCH:33-find-users-with-persistent-behavior-patterns -->
<!-- /BENCH -->

### Why the optimal one wins

Approach 3 does the minimum number of full-size passes: one streaming `GROUP BY` and one sort. Everything after the island step works on streaks, not days. It also has the fewest places to go wrong. The gap logic is implicit in the date arithmetic, so a removed day splits the streak without any code saying so. Approach 2 is the one to switch to when "consecutive" stops meaning "exactly 1 day apart". Approach 1 is correct, but its cost depends on how many rows each user has, which is exactly what skewed real data makes large.

## 6. At scale

**(a) What breaks first.** *Reasoned, then checked by the bench table:* approach 1 on heavy users, because each streak start re-reads the user's history. Then approach 2's chain of materialised window CTEs, once they spill to disk. Approach 3 is bounded by one sort of the clean days.

**(b) One machine, ~1M–100M rows.**
- The primary key (`user_id`, `action_date`, `action`) is already the right index for step 1: the clean-day `GROUP BY` reads it in order with no temporary table.
- `indexes.sql` adds (`user_id`, `action`, `action_date`). It turns approach 1's end-of-streak probe from "all rows of the user" into "rows of this user and action from the start date on" (EXPLAIN shows the new index chosen). It cannot remove the sort in approaches 2 and 3, because the window runs over the materialised `clean` CTE, not over the base table. The "with indexes" bench table shows whether it matters.
- Approach 3 can avoid that sort by labelling *before* materialising: compute `ROW_NUMBER()` directly over `activity` with an anti-join filter (approach 1's `NOT EXISTS`) in the same `SELECT`. Then the window could read the new index in order. This is reasoned, and it is only worth trying if the bench shows the sort dominating.
- Heavy users do not create skew on one machine. They only make approach 1 worse.

**(c) Distributed engines, billions of rows. *Reasoned, not measured.***
- *Partitioning is natural.* Every window is partitioned by `user_id` (plus `action`), so a Spark-style engine shuffles once by `user_id` and does everything else locally. Step 1's `GROUP BY user_id, action_date` can reuse the same shuffle if the planner partitions by `user_id` only. Ask for that explicitly (repartition by `user_id`), otherwise it may shuffle on (user, day) and then again on (user, action).
- *Skew:* a handful of bot users with years of daily activity become single huge partitions. Salting does not work for an ordered window, because a streak can cross salt buckets. The practical fix is to split heavy users by time range (for example by month), compute islands per range, and stitch streaks that touch a range boundary, the same seam trick as in `32-human-traffic-of-stadium`.
- *Pruning:* if the question is bounded ("streaks in the last 90 days"), a date predicate prunes partitions in Snowflake. Careful: a streak that started before the window would be cut, so pad the window by the longest streak you care about, or carry streak state forward (d).
- *No COUNT DISTINCT* and no global sort are needed until the final `ORDER BY`, which runs over at most one row per user.

**(d) The data-engineering answer.** Streaks are a classic state machine, and you should not recompute them from history every day. Keep one row per (user, action) holding the *open* streak (`streak_start`, `last_day`, `length`) plus the user's best streak so far. Each day's batch either extends the open streak (`day = last_day + 1`), closes it and starts a new one, or (for multi-action days) closes every open streak of that user:

```sql
-- daily_clean: one row per (user_id, action_date) with a single action, for the new day only.
-- user_streaks(user_id, action, streak_start, last_day, length, PRIMARY KEY (user_id, action)).
-- Snowflake / ANSI MERGE (UNVERIFIED): extend or restart the open streak.
MERGE INTO user_streaks t
USING daily_clean s
ON t.user_id = s.user_id AND t.action = s.action
WHEN MATCHED AND s.action_date = t.last_day + 1 THEN
  UPDATE SET last_day = s.action_date, length = t.length + 1
WHEN MATCHED AND s.action_date > t.last_day + 1 THEN
  UPDATE SET streak_start = s.action_date, last_day = s.action_date, length = 1
WHEN NOT MATCHED THEN
  INSERT (user_id, action, streak_start, last_day, length)
  VALUES (s.user_id, s.action, s.action_date, s.action_date, 1);
-- A second statement folds any streak that just reached a new length into user_best
-- (one row per user: longest length, earliest start on ties).
```

Caveats that interviewers probe. *Late data*: an event for an old day can merge two streaks or (as a second action) remove a day in the middle. The state machine cannot absorb that, so re-run the batch computation for that user from the earliest affected day. *Idempotency*: the two `WHEN MATCHED` guards already make a re-applied day a no-op (it is neither `last_day + 1` nor later). Days applied out of order are not safe, so the loader must apply days strictly in date order. *Multi-action detection* needs the whole day's rows, so the daily batch must be complete before it is applied.

## 7. Edge cases

Each "breaks" claim below is checked by execution: `mistakes/*.sql` are the tempting wrong queries, and the harness asserts that each one fails every dataset it names (`harness/test_mistakes.py`).

| Case | Dataset | Wrong queries it catches (`mistakes/`) |
|---|---|---|
| Streaks of 6, 4 and exactly 5 days | `tests/edge_typical.sql` | `strictly_more_than_5` |
| Two qualifying streaks for one user; the later one is longer | `tests/edge_longest_per_user.sql` | `every_streak_not_longest` |
| A multi-action day inside a streak (its extra action sorts after the streak's action) | `tests/edge_multi_action_day.sql` | `no_multi_action_filter`, `keep_one_action_per_day` (reduces the day to `MIN(action)` instead of removing it), `strictly_more_than_5` |
| Six active days in a row, but the action changes in the middle | `tests/edge_action_change.sql` | `partition_by_user_only`, `strictly_more_than_5` |
| Streaks across 12-31 → 01-01 and 02-28 → 03-01 (non-leap year); two users tied on length | `tests/edge_calendar_boundaries.sql` | `numeric_date_minus_row_number` (MySQL date-to-number arithmetic), `strictly_more_than_5` |
| Two equally long longest streaks for one user (Assumption 1) | `tests/edge_tied_longest.sql` | `tie_break_by_action`, `every_streak_not_longest`, `strictly_more_than_5` |
| Nine active days; removing one multi-action day leaves 4 + 4 | `tests/edge_no_streak.sql` | `no_multi_action_filter`, `keep_one_action_per_day` |
| Output order: a longer streak with a higher user id comes first | `tests/edge_ordering.sql` | none reliably; every approach sorts explicitly |

NULLs are not possible: every column is part of the primary key. No approach in `solutions/` is broken by any of these.

## 8. Interviewer follow-ups

1. **"Allow one missed day inside a streak."** The `date - rn` label no longer works, because it encodes "exactly 1 day apart". Switch to approach 2 with `is_start = CASE WHEN DATEDIFF(action_date, LAG(action_date) OVER w) <= 2 THEN 0 ELSE 1 END`. Decide whether `streak_length` then counts active days or calendar days.
2. **"Report every user's longest streak, even if it is under 5."** Move the `>= 5` out of `HAVING` and into nothing at all. The rank step already picks the longest. Users whose clean days are all isolated still appear, with length 1.
3. **"Return all tied longest streaks."** Use `RANK()` instead of `ROW_NUMBER()` and drop `start_date` from its `ORDER BY`. The output grain becomes (user, streak), so say so.
4. **"What if a multi-action day should only break streaks, not remove the user's other actions?"** It already only affects that day. If the rule became "ignore the extra actions but keep the day", step 1 would need a priority rule to choose the day's action, and that is a different problem (see `mistakes/keep_one_action_per_day.sql`).
5. **"Why not `action_date - ROW_NUMBER()`?"** In MySQL a `DATE` in arithmetic becomes `YYYYMMDD` as a number, so 2024-01-01 − 3 is 20240098. The label is then not constant across a month end. Use `DATE_SUB(…, INTERVAL rn DAY)` or `DATEDIFF(action_date, '1970-01-01') - rn`.

## 9. Snowflake notes (UNVERIFIED)

`snowflake.sql` keeps the shape of approach 3. What changes, and why:

- `DATEADD(day, -ROW_NUMBER() OVER (…), action_date)` is the label. Snowflake's `date - integer` also subtracts days, so the MySQL number trap does not exist there. It is still worth writing `DATEADD` so the query ports back.
- `QUALIFY` removes two levels: `QUALIFY COUNT(*) OVER (PARTITION BY user_id, action_date) = 1` for clean days, and `QUALIFY ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY streak_length DESC, start_date) = 1` for the longest streak.
- `MAX_BY(action, …)` and similar functions are not needed: `QUALIFY` keeps the whole row.
- A clustering key on `user_id` is rarely worth it for this alone. The windows shuffle by `user_id` anyway, and the cost is dominated by the sort within each user.

## 10. Pattern links

Same pattern (gaps and islands):
- `32-human-traffic-of-stadium`: islands on an integer id, with no partition and row-grain output.
- `31-consecutive-numbers`: fixed-length runs with LAG/LEAD.

Related:
- `16-department-highest-salary`, `19-department-top-three-salaries`: the step 4 move (top-1 per group with a tie rule).
- `38-find-students-with-study-spiral-pattern`: per-user ordered sequences with a gap rule (`DATEDIFF` with `LAG`), the approach 2 style.
