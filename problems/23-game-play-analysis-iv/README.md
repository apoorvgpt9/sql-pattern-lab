# 23 · Game Play Analysis IV

## 1. Problem & trigger phrases

Original: [Game Play Analysis IV](https://leetcode.com/problems/game-play-analysis-iv/) (LeetCode 550, medium). Read the statement there; this guide only restates the spec in its own words.

**Spec (own words):** for each player, take the date of their first-ever activity. A player is *retained on day 1* if they also have an activity row dated exactly one calendar day after that. Return a single number: the share of all players who are retained on day 1, rounded to 2 decimals.

| Trigger phrase | What it forces in SQL |
|---|---|
| "the day they first logged in" | A per-player anchor: `MIN(event_date)` per `player_id`, or the first row of a window ordered by date. Everything else is measured relative to this anchor, not to any other login. |
| "logged in again on the day after" | A test for the existence of a row at `anchor + 1 day`: an equality on a **date**, written with `DATE_ADD(anchor, INTERVAL 1 DAY)` (or `DATEDIFF = 1`), never with plain integer arithmetic. It must be the day after the **first** login, not any pair of consecutive days. |
| "divide it by the number of total players" | The denominator is **all distinct players**, including those with a single login and those who never return. A denominator taken from the joined set (only returners) gives 1.00. |

## 2. Schema & grain

| Table | One row means | Keys that matter here |
|---|---|---|
| `Activity` | one player was active on one day (on some device) | primary key `(player_id, event_date)`; `device_id` and `games_played` are irrelevant here |

**Output grain:** one scalar row with one column, `fraction`.

**Where the grain changes:** two collapses. Activity rows → **one row per player** (the anchor and the retained flag), and players → **one number**. The ratio is `retained players / all players`, so both counts must be at player grain: counting rows of `Activity` (several per player) in either position is wrong.

The key `(player_id, event_date)` gives a useful guarantee: at most one row per player per day, so there is at most one row at `anchor + 1`, and a join on the next-day condition cannot multiply a player.

## Assumptions

- **Empty `Activity`.** The spec says this is not tested. For completeness, `0 / 0` is undefined, and MySQL evaluates it to `NULL` in a `SELECT` (the strict-mode division-by-zero error applies to writes, not to reads). All three approaches return `NULL`; `tests/edge_empty.sql` records it. Do not rely on it as part of the original problem.
- **Rounding.** `ROUND(x, 2)` on MySQL's exact decimal quotient (integer division gives a DECIMAL with four extra places, `div_precision_increment = 4`). Halves round away from zero: 1/8 = 0.1250 → 0.13. `tests/edge_rounding_half.sql` pins this down; `TRUNCATE` would give 0.12.
- **The anchor is per player,** not per (player, device). Playing on another device the next day counts (`tests/edge_typical.sql`, player 4).

## 3. Hint ladder

<details><summary>Hint 1</summary>

Pattern: **day-N retention from a first-event anchor** (a cohort metric). Find each player's first date, test whether there is activity exactly N days later, and average the yes/no flag over all players.

</details>

<details><summary>Hint 2</summary>

Shape: (1) one row per player with their first login date. (2) For each of those rows, check whether an `Activity` row exists exactly one day later. (3) Divide the number of players with a match by the number of all players; round.

</details>

<details><summary>Hint 3</summary>

Key trick: keep the players who did **not** match in the denominator. `LEFT JOIN` from the one-row-per-player set to the next-day row and average a 0/1 flag; or, in a window, look at the second row of the player's history with `LEAD` and test `DATEDIFF(next_date, first_date) = 1`. Use date functions for "plus one day", never `date + 1`.

</details>

## 4. Decomposition

"Fraction of players … retained" = `retained players / all players`. Both counts need one row per player, so first build that set.

1. **`x`: for each player's rows, number them by date and look one row ahead.**
   *Why a window function here:* we need, for each player, the first activity date and the *next* activity date. With rows ordered by date inside each player, row 1 is the first login and `LEAD(event_date)` on that row is the second active day. This avoids both a `GROUP BY` and a join back.
2. **Keep `rn = 1`.**
   *Why a filter here:* it leaves exactly one row per player, which is the grain the ratio needs, and it makes the denominator "all players" without a separate count.
3. **Flag and average.**
   *Why a conditional and AVG here:* `CASE WHEN DATEDIFF(next_date, event_date) = 1 THEN 1 ELSE 0 END` is the "retained" flag at player grain; its average over all players is the fraction. The `ELSE 0` matters: without it, a population with no returners averages over nothing (NULL), not 0. `DATEDIFF = 1` is "exactly one calendar day later" and handles month ends, year ends and leap days.

```sql
WITH x AS (
  SELECT event_date,
         ROW_NUMBER()     OVER w AS rn,         -- step 1
         LEAD(event_date) OVER w AS next_date
  FROM Activity
  WINDOW w AS (PARTITION BY player_id ORDER BY event_date)
)
SELECT ROUND(AVG(CASE WHEN DATEDIFF(next_date, event_date) = 1 THEN 1 ELSE 0 END), 2) AS fraction   -- step 3
FROM x
WHERE rn = 1;                                                                                          -- step 2
```

Self-check before you submit: the number of rows after step 2 equals `SELECT COUNT(DISTINCT player_id) FROM Activity`. Then test a player whose first login is on a month end, and a player with later consecutive days.

## 5. Approaches: brute force → optimal

### Approach 1: first logins, join to the next day, divide by a separate count (`solutions/01_join_first_login_and_count.sql`)

```sql
SELECT ROUND(COUNT(DISTINCT a.player_id) / (SELECT COUNT(DISTINCT player_id) FROM Activity), 2) AS fraction
FROM (SELECT player_id, MIN(event_date) AS first_login FROM Activity GROUP BY player_id) f
JOIN Activity a
  ON a.player_id = f.player_id AND a.event_date = DATE_ADD(f.first_login, INTERVAL 1 DAY);
```

**Why it is correct:** the derived table is the per-player anchor; the inner join keeps those with a row exactly one day later (at most one by the primary key); the numerator counts distinct such players. The denominator is a separate scalar subquery over *all* players, so it is not affected by the join. The two counts are computed separately, which is why it reads like the problem statement.

**Cost model (reasoned):** three reads of `Activity`: one `GROUP BY` for the anchors, one join back (a point lookup per player through the primary key `(player_id, event_date)`), and one `COUNT(DISTINCT player_id)` for the denominator. With the clustered primary key, the group-by and the distinct count can be answered from the key order; there is no quadratic step.

### Approach 2: `ROW_NUMBER` + `LEAD` in one pass (`solutions/02_first_row_and_lead.sql`)

The SQL is the assembled query in section 4.

**Why it is correct:** within a player's rows ordered by date, `rn = 1` is the first activity and `LEAD(event_date)` at that row is the second distinct day (the key forbids duplicate days). `DATEDIFF(…) = 1` is exactly "second active day is the day after the first". `WHERE rn = 1` leaves one row per player, so `AVG` is over all players.

**Cost model (reasoned):** one scan of `Activity` in primary-key order `(player_id, event_date)`, which is already the window's partition and order, so there is no extra sort; then a filter and a single aggregate over one row per player. No joins, no second read, no separate distinct count. The catch is that every one of the `Activity` rows goes through the window evaluation (row numbering and `LEAD`), although only the first two rows of each player matter.

### Approach 3 (optimal): `LEFT JOIN` and average the flag (`solutions/03_left_join_average.sql`)

```sql
SELECT ROUND(AVG(a.player_id IS NOT NULL), 2) AS fraction
FROM (SELECT player_id, MIN(event_date) AS first_login FROM Activity GROUP BY player_id) f
LEFT JOIN Activity a
  ON a.player_id = f.player_id AND a.event_date = DATE_ADD(f.first_login, INTERVAL 1 DAY);
```

**Why it is correct:** the `LEFT JOIN` keeps every player; `a.player_id IS NOT NULL` is 1 where the next-day row exists and 0 where it does not, so its average is the retained share of all players. Putting the next-day condition in `ON` (not `WHERE`) is what keeps the non-returners; this is the same filter-placement rule as problem 01.

**Cost model (reasoned):** two reads of `Activity` (the group-by and the join back) and no separate distinct count. The join output has one row per player, because at most one row matches. Because the primary key is `(player_id, event_date)`, `MIN(event_date)` per player needs only the first index entry of each player (a loose index scan is possible), and the join back is a point lookup per player. The work is proportional to the number of players, not the number of activity rows, which is where the window form spends its time.

**Measured** (`gen.py` data, generated by the bench workflow; the table is filled in automatically, so never type numbers here):

<!-- BENCH:23-game-play-analysis-iv -->
<!-- /BENCH -->

### Why the optimal one wins

Approach 3 exploits the primary key `(player_id, event_date)`: the first login of every player is the first index entry of that player, and "the day after" is one point lookup, so the work grows with the number of players. Approach 1 does the same plus an extra distinct count over all rows. Approach 2 is the most elegant, one ordered pass that yields the anchor, the next date and the denominator together, but it evaluates a window over every row of `Activity` while only two rows per player matter, so on MySQL it is expected to cost more. The bench table is the arbiter; in a distributed engine without a clustered key the balance can flip, because the join back is a second shuffle where the window needs one (section 6c). Teaching-wise, approach 2 is the form to learn first for day-N retention (it generalises to "the n-th event"), and approach 3 is the one to ship when the key order is right.

## 6. At scale

**(a) What breaks first.** *Reasoned, then checked by the bench table:* nothing is quadratic here, thanks to the primary key. Approach 2 is expected to slow down first as `Activity` grows, because every row passes through the window while the join-back forms touch only about one row per player. Approach 1 adds a separate distinct count on top of approach 3's work.

**(b) One machine, ~1M–100M rows.**
- `Activity`'s primary key `(player_id, event_date)` is clustered, so the table is stored in the exact order that the window, the `MIN(event_date)` group-by and the next-day point lookups need. No secondary index would help (and `indexes.sql` is absent for that reason). If the table had a surrogate key instead, the index to add is `(player_id, event_date)`.
- Do not add an index on `event_date` alone: the question is per player, not per day.
- If this metric is computed daily, restrict the work: a player's first login is fixed once written, so only players whose first login is on day D − 1 need their day-1 check on day D (section 6d).

**(c) Distributed engines, billions of rows. *Reasoned, not measured.***
- *Shuffle:* the window shuffles every row by `player_id` once. The join-back forms' group-by can pre-aggregate `MIN(event_date)` per player locally (decomposable), shuffling one row per (task, player), but then needs a second pass to find the next-day row (a join, hence another shuffle or a broadcast of a very large anchor table, which usually does not fit). So the window is likely to move fewer bytes unless the data is already clustered by `player_id`.
- *Skew:* a few bot players with enormous histories give one worker a huge partition. Restrict to each player's two earliest rows before the window if that matters (`MIN` over the date, then a join on a narrow range).
- *Snowflake:* `QUALIFY ROW_NUMBER() … = 1` keeps the first row while `LEAD` still sees all rows. Clustering by `player_id` helps the partition. No indexes.
- *Things to avoid:* `COUNT(DISTINCT player_id)` over billions of rows when the exact value is not needed (`APPROX_COUNT_DISTINCT` is acceptable for a dashboard metric, not for an audited number), and a global sort.

**(d) The data-engineering answer.** Retention is an incremental, cohort-shaped metric: maintain `player_first(player_id, first_login)` once and a `retained_d1(player_id)` set, both append-only:

```sql
-- player_first(player_id PK, first_login DATE): written once, never updated
-- Snowflake / ANSI MERGE (UNVERIFIED): register players seen for the first time in a batch.
MERGE INTO player_first t
USING (SELECT player_id, MIN(event_date) AS first_login FROM activity_batch GROUP BY player_id) s
ON t.player_id = s.player_id
WHEN MATCHED AND s.first_login < t.first_login THEN UPDATE SET first_login = s.first_login   -- late/back-dated data
WHEN NOT MATCHED THEN INSERT (player_id, first_login) VALUES (s.player_id, s.first_login);

-- Day-1 check for the cohort whose "day after" is now in the data:
INSERT INTO retained_d1 (player_id)
SELECT f.player_id
FROM player_first f
JOIN activity_batch a ON a.player_id = f.player_id AND a.event_date = DATEADD(day, 1, f.first_login)
WHERE NOT EXISTS (SELECT 1 FROM retained_d1 r WHERE r.player_id = f.player_id);

-- The report: SELECT ROUND(COUNT(*) / (SELECT COUNT(*) FROM player_first), 2) FROM retained_d1;
```

Caveats interviewers probe: **a cohort is only measurable after its day 1 has elapsed**, so the most recent day's cohort is incomplete and should be excluded or flagged; a back-dated event that moves a player's `first_login` earlier invalidates their previous retained flag, and the flag must be recomputed from the detail; and counting must be idempotent (the `NOT EXISTS` above).

## 7. Edge cases

Each "breaks" claim below is checked by execution: `mistakes/*.sql` are the tempting wrong queries, and the harness asserts that each one fails every dataset it names (`harness/test_mistakes.py`).

| Case | Dataset | Wrong queries it catches (`mistakes/`) |
|---|---|---|
| Returner on another device; player returning after two days; a single-login player | `tests/edge_typical.sql` | `first_login_per_device` (anchor per device), `denominator_only_returners` (always 1.00), `count_rows_not_players` |
| Consecutive days later in the history, but none right after the first login; a player with three consecutive days (counted once) | `tests/edge_later_consecutive.sql` | `any_consecutive_pair`, `denominator_only_returners`, `count_rows_not_players`, `truncate_instead_of_round` |
| First login on Jan 31, Dec 31 and Feb 28 (leap and non-leap year); in a leap year the day after Feb 28 is Feb 29, so a Mar 1 return does not count | `tests/edge_date_boundaries.sql` | `integer_date_arithmetic` (`date + 1` is the number 20230132), `truncate_instead_of_round` |
| 1/8 = 0.125 rounds to 0.13 | `tests/edge_rounding_half.sql` | `truncate_instead_of_round`, `count_rows_not_players`, `denominator_only_returners` |
| No player returns: 0.00 and not NULL | `tests/edge_none_return.sql` | `sum_case_without_else`, `denominator_only_returners` |
| `Activity` empty (not tested by the spec) | `tests/edge_empty.sql` | none; all approaches return `NULL`, see Assumptions |

No approach in `solutions/` is broken by any of these.

## 8. Interviewer follow-ups

1. **"Day-7 retention instead of day-1."** Change `INTERVAL 1 DAY` to 7. Note that "retained on day 7" means active *exactly* 7 days after the first login, not "active within the first week"; the latter is `event_date BETWEEN first+1 AND first+7` with a distinct count. Ask which one is meant.
2. **"Retention for every day 1 to 30, as a curve."** Join each player's anchor to all of their activity, compute `DATEDIFF(event_date, first_login)` as `n`, and `GROUP BY n` with `COUNT(DISTINCT player_id)` divided by the cohort size. That is the cohort table; it needs the cohort size computed once, not per row.
3. **"Per cohort week."** Add `DATE_FORMAT(first_login, …)` or `DATE_SUB(first_login, INTERVAL WEEKDAY(first_login) DAY)` to the grouping; the denominator becomes the cohort's own player count.
4. **"Why not `event_date = first_login + 1`?"** Date plus integer is numeric in MySQL: `2023-01-31 + 1` is `20230132`, which is not a date. It happens to be right within a month, which is exactly why it survives testing (`mistakes/integer_date_arithmetic.sql`). Use `DATE_ADD` or `DATEDIFF`.
5. **"What about players whose first login is today?"** Their day 1 has not happened yet. They are in the denominator but cannot be in the numerator, which biases the metric down; production retention reports exclude the incomplete cohort.

## 9. Snowflake notes (UNVERIFIED)

`snowflake.sql` is the window form (approach 2). What changes, and why:

- `QUALIFY ROW_NUMBER() OVER (...) = 1` replaces the `rn` column and the `WHERE`. `LEAD` is still computed over every row of the player because window functions are evaluated before `QUALIFY` filters, so the second row is visible while the first is kept.
- `DATEDIFF('day', event_date, next_date) = 1` takes the unit first and the arguments in (start, end) order, the reverse of MySQL's two-argument `DATEDIFF(end, start)`. Getting the sign wrong turns the test into `= -1`, and the result into 0.00.
- `IFF(cond, 1, 0)` replaces `CASE`. `AVG` over `NUMBER` returns a `NUMBER` with scale; `ROUND(…, 2)` behaves like MySQL's on exact numbers (half away from zero).
- No secondary indexes; clustering by `player_id` is the lever. Integer-style date arithmetic (`date + 1`) *works* in Snowflake (it adds a day) and does not in MySQL: another reason to write the interval explicitly.

## 10. Pattern links

Same pattern (first event per key as the anchor of a measure):
- `24-immediate-food-delivery-ii`: first order per customer, then a ratio over those rows (percentage instead of fraction, a conditional average over the first-row set).
- `20-product-sales-analysis-iii`: first year per product, keeping all rows of it.
- `22-find-students-who-improved`: first and last row per group.
- `21-product-price-at-a-given-date`: an as-of row per key with a default.
- `33-find-users-with-persistent-behavior-patterns`: consecutive-day logic (runs) over a player's history, the general form of the "consecutive pair" trap in section 7.
- `36-find-churn-risk-customers`: latest vs. earlier behaviour per customer.
