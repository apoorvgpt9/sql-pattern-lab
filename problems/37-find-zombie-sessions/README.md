# 37 · Find Zombie Sessions

## 1. Problem & trigger phrases

Original: [Find Zombie Sessions](https://leetcode.com/problems/find-zombie-sessions/) (LeetCode 3673, hard). Read the statement there; this guide only restates the spec in its own words.

**Spec (own words):** for each session, measure its length in whole minutes from its first event to its last, and count its scrolls, clicks and purchases. A session is a *zombie* if it is longer than 30 minutes, has at least 5 scrolls, has fewer than 0.20 clicks per scroll, and has no purchase. Report the zombie sessions with their user, duration and scroll count. Most scrolls first, then by session id.

| Trigger phrase | What it forces in SQL |
|---|---|
| "session duration is more than 30 minutes" | Per-session `MIN`/`MAX` of the timestamp over **all** event types (app_open and app_close count). `TIMESTAMPDIFF(MINUTE, …)` gives whole minutes and truncates, so 30:59 is 30. Strict `>`; see Assumptions. |
| "at least 5 scroll events" | A count of one event type inside the group: `SUM(event_type = 'scroll') >= 5`. Do not write `COUNT(event_type = 'scroll')`: COUNT counts FALSE too. |
| "click-to-scroll ratio is less than 0.20" | Two conditional counts, divided: `SUM(click) / SUM(scroll) < 0.20`. The denominator is scrolls, not all events. Strict `<`, and MySQL's `1/5` is exactly `0.2000`. |
| "No purchases" | `SUM(event_type = 'purchase') = 0`, an existence test on the event *type*, not on the amount. |

## 2. Schema & grain

| Table | One row means | Keys that matter here |
|---|---|---|
| `app_events` | one event in one session | `session_id`, `user_id`, `event_timestamp`, `event_type`. `event_value` is irrelevant. |

**Output grain:** one row per zombie session.

**Where the grain changes:** once, from event to session, and every rule is a test on the session group. That makes this the cleanest shape in the batch: a single `GROUP BY session_id` with every condition in `HAVING`. The difficulty lies in the details of each aggregate, not in the structure:

- the duration must see **every** event, so no `WHERE` filter on `event_type` before grouping;
- the counts must count **one** event type each, which is `SUM` over a boolean;
- the ratio's denominator is the scroll count, which the `>= 5` rule guarantees is non-zero, so no division by zero is possible in any row that reaches the ratio test.

`user_id` goes in the `GROUP BY` as an attribute of the session (see Assumptions). Grouping by user instead merges a user's sessions.

## Assumptions

Confidence is `medium`. Each interpretation is tested by a dataset.

1. **Duration must be strictly more than 30 whole minutes.** The `requirement` says "> 30"; the reference solution the spec was drawn from uses `>= 30`. CLAUDE.md makes the `requirement` the source of truth. Tested by `tests/edge_duration_boundary.sql`, where d3 lasts exactly 30:00 and is excluded. `mistakes/duration_at_least_30.sql` is the `>=` version and fails it.
2. **"Whole minutes" means `TIMESTAMPDIFF(MINUTE, first, last)`, which truncates.** 30 min 59 s is 30, so it is not a zombie. Tested by d1 in the same dataset. `mistakes/fractional_minutes.sql` (seconds ÷ 60 = 30.98 > 30) fails it.
3. **Each `session_id` belongs to one user.** The spec reports one `user_id` per session. The solutions group by (`session_id`, `user_id`), so a session id shared by two users would appear twice, once per user. `gen.py` never generates that, and no edge dataset depends on it. If the data can violate it, that is a data-quality bug to surface, not to hide with `MIN(user_id)`.

## 3. Hint ladder

<details><summary>Hint 1</summary>

Pattern: **conditional aggregation** over one grouping key (session), with all rules in `HAVING`.

</details>

<details><summary>Hint 2</summary>

Shape: (1) group events by session. (2) In the same pass, compute the first and last timestamps, the number of scrolls, clicks and purchases. (3) Keep groups that meet the four rules. (4) Sort.

</details>

<details><summary>Hint 3</summary>

Key trick: in MySQL a comparison is 1 or 0, so `SUM(event_type = 'scroll')` counts scrolls in the same pass as everything else. Put the four rules in `HAVING` with `TIMESTAMPDIFF(MINUTE, MIN(event_timestamp), MAX(event_timestamp)) > 30` for the duration. Do not filter event types in `WHERE`, because the duration needs app_open and app_close.

</details>

## 4. Decomposition

All four rules are about the same thing, a session, so they collapse into one aggregation level. The skill is recognising that four sentences do not mean four queries.

1. **Group: `GROUP BY session_id, user_id` over the whole table, no `WHERE`.**
   *Why a GROUP BY here:* "session duration", "scroll events", "ratio" and "purchases" are all per-session quantities. *Why no WHERE:* the duration rule needs every event type, and the counts can filter inside the aggregate instead (`SUM(cond)`). A `WHERE event_type IN (…)` would silently shorten sessions.
2. **Metrics, same SELECT: `TIMESTAMPDIFF(MINUTE, MIN(event_timestamp), MAX(event_timestamp))`, `SUM(event_type = 'scroll')`, `SUM(event_type = 'click')`, `SUM(event_type = 'purchase')`.**
   *Why conditional aggregation:* each count depends on a different event type, but all of them come from one pass over the same group. `SUM(boolean)` is MySQL's `COUNT_IF`.
3. **Rules: `HAVING duration > 30 AND scrolls >= 5 AND clicks / scrolls < 0.20 AND purchases = 0`.**
   *Why HAVING:* these test aggregates, which only exist after grouping. The order of the ANDs does not matter for correctness. `scrolls >= 5` is what keeps `clicks / scrolls` away from division by zero in every row that passes.
4. **`ORDER BY scroll_count DESC, session_id`.** One row per session, so no ties remain.

```sql
SELECT session_id, user_id,                                             -- step 1: session grain
       TIMESTAMPDIFF(MINUTE, MIN(event_timestamp), MAX(event_timestamp)) AS session_duration_minutes,
       SUM(event_type = 'scroll') AS scroll_count                       -- step 2: metrics
FROM app_events
GROUP BY session_id, user_id
HAVING TIMESTAMPDIFF(MINUTE, MIN(event_timestamp), MAX(event_timestamp)) > 30   -- step 3: rules
   AND SUM(event_type = 'scroll') >= 5
   AND SUM(event_type = 'click') / SUM(event_type = 'scroll') < 0.20
   AND SUM(event_type = 'purchase') = 0
ORDER BY scroll_count DESC, session_id;                                  -- step 4
```

Arithmetic check (MySQL): `1 / 5` is `0.2000`, which is not `< 0.20`, and `1 / 6` is `0.1667`, which is. `0 / 6` is `0.0000`. `TIMESTAMPDIFF(MINUTE, '08:00:00', '08:30:59')` is 30.

## 5. Approaches: brute force → optimal

### Approach 1: correlated subquery per metric (`solutions/01_correlated_metrics.sql`)

```sql
WITH sessions AS (SELECT DISTINCT session_id, user_id FROM app_events),
metrics AS (
  SELECT s.session_id, s.user_id,
         (SELECT TIMESTAMPDIFF(MINUTE, MIN(a.event_timestamp), MAX(a.event_timestamp))
            FROM app_events a WHERE a.session_id = s.session_id) AS duration_min,
         (SELECT COUNT(*) FROM app_events a
           WHERE a.session_id = s.session_id AND a.event_type = 'scroll')   AS scrolls,
         (SELECT COUNT(*) FROM app_events a
           WHERE a.session_id = s.session_id AND a.event_type = 'click')    AS clicks,
         (SELECT COUNT(*) FROM app_events a
           WHERE a.session_id = s.session_id AND a.event_type = 'purchase') AS purchases
  FROM sessions s
)
SELECT session_id, user_id, duration_min AS session_duration_minutes, scrolls AS scroll_count
FROM metrics
WHERE duration_min > 30 AND scrolls >= 5 AND clicks / scrolls < 0.20 AND purchases = 0
ORDER BY scroll_count DESC, session_id;
```

**Why it is correct:** every metric is computed exactly as the spec words it, one session at a time. `COUNT(*)` over zero rows is 0, so a session with no clicks gets 0 clicks for free. A session with no scrolls makes `clicks / scrolls` a division by zero. In a MySQL `SELECT` that evaluates to NULL (with a warning, not an error), and NULL fails `< 0.20`, so the row is filtered out whichever condition MySQL evaluates first.

**Cost model (reasoned from EXPLAIN):** four *dependent* subqueries per distinct session. Without an index each one scans the whole table, so the cost is sessions × events × 4, which is quadratic. With `indexes.sql`, each becomes a short index range read of one session. It is correct and natural, but it rereads every session four times even in the best case.

### Approach 2: one CTE per metric, joined (`solutions/02_metric_ctes_joined.sql`)

```sql
WITH durations AS (
  SELECT session_id, user_id,
         TIMESTAMPDIFF(MINUTE, MIN(event_timestamp), MAX(event_timestamp)) AS duration_min
  FROM app_events GROUP BY session_id, user_id
),
scrolls AS (SELECT session_id, COUNT(*) AS n FROM app_events WHERE event_type = 'scroll' GROUP BY session_id),
clicks  AS (SELECT session_id, COUNT(*) AS n FROM app_events WHERE event_type = 'click'  GROUP BY session_id)
SELECT d.session_id, d.user_id, d.duration_min AS session_duration_minutes, s.n AS scroll_count
FROM durations d
JOIN scrolls s     ON s.session_id = d.session_id
LEFT JOIN clicks c ON c.session_id = d.session_id
WHERE d.duration_min > 30 AND s.n >= 5
  AND COALESCE(c.n, 0) / s.n < 0.20
  AND NOT EXISTS (SELECT 1 FROM app_events p
                  WHERE p.session_id = d.session_id AND p.event_type = 'purchase')
ORDER BY scroll_count DESC, d.session_id;
```

**Why it is correct:** each CTE is one rule's input. The durations CTE sees every event, so app_open and app_close count. Scrolls use an inner join because a session with no scrolls cannot qualify. Clicks need a LEFT JOIN plus `COALESCE`, because zero clicks is the most common zombie and has no row in `clicks`. Purchases are an anti-join.

**Cost model (reasoned from EXPLAIN):** four scans of `app_events` (three aggregations and the anti-join's materialised `<subquery5>`), each with its own temporary table, then nested-loop joins through auto-keys. The cost is linear, but about 4× the reading of approach 3. It is the shape people write when they translate each sentence separately, and the LEFT JOIN plus `COALESCE` for clicks is an easy place to slip.

### Approach 3 (optimal): one GROUP BY with conditional aggregation (`solutions/03_conditional_aggregation.sql`)

The SQL is the assembled query in section 4.

**Why it is correct:** one group per session. `MIN`/`MAX` over all its events give the duration, and each `SUM(event_type = …)` counts exactly one type. `HAVING` applies the four rules to the group.

**Cost model (reasoned from EXPLAIN):** a single scan. Without an index MySQL uses `Aggregate using temporary table` (a hash-style group by on `session_id`). With `indexes.sql`, whose prefix is (`session_id`, `user_id`), EXPLAIN switches to a streaming `Group aggregate` over the covering index, with no temporary table at all. The final sort is over zombie sessions only.

**Measured** (`gen.py` data, generated by the bench workflow; the table is filled in automatically, so never type numbers here):

<!-- BENCH:37-find-zombie-sessions -->
<!-- /BENCH -->

### Why the optimal one wins

Every rule is a property of the same group, so one pass computes all of them. Approach 3 reads each event once, keeps one small accumulator per session, and needs no joins. Approach 2 reads the table four times to build the same accumulators separately and then pays to join them back together. Approach 1 does the same work per session with lookups. The general rule: when several conditions share a grouping key, merge them into one `GROUP BY` with conditional aggregates instead of one query per condition.

## 6. At scale

**(a) What breaks first.** *Reasoned, then checked by the bench table:* approach 1 without the index (quadratic). Then approach 2's four temporary tables. Approach 3 last; once its temporary table outgrows `tmp_table_size` it spills to disk, and `indexes.sql` removes the temporary table entirely.

**(b) One machine, ~1M–100M rows.**
- `indexes.sql`: `(session_id, user_id, event_type, event_timestamp)`. It is covering, and its prefix matches the `GROUP BY`, so approach 3 streams. Putting `event_type` second would serve approaches 1–2 slightly better and cost approach 3 its streaming plan. Optimise for the query you will keep.
- `session_id` is a `VARCHAR`. A compact integer surrogate key makes both the index and the group by smaller (reasoned).
- If the question is "zombie sessions yesterday", add a date range. Then an index leading with `event_timestamp` competes: it gives a range scan, but loses the streaming group by. At 1–5% selectivity the range scan usually wins (reasoned).

**(c) Distributed engines, billions of rows. *Reasoned, not measured.***
- *Shuffle:* one shuffle by `session_id`. All four aggregates are decomposable (`MIN`, `MAX`, `SUM`), so each task pre-aggregates its events locally and ships one small accumulator per session. Approach 2's four separate aggregations would shuffle four times and then join.
- *Sessions that span partitions:* if events are stored partitioned by date, a session that crosses midnight lives in two partitions. This is harmless for a global `GROUP BY session_id`, but it breaks a "process one day's partition at a time" job: the session's duration is cut at midnight. The midnight-crossing session in `tests/edge_typical.sql` is the miniature version.
- *Skew:* bot sessions with millions of events concentrate on one key. Pre-aggregation handles it, because each task sends one accumulator per session no matter how many events it saw.
- *No COUNT DISTINCT, no global sort* until the final `ORDER BY`, which runs over zombie sessions only.

**(d) The data-engineering answer.** Sessions end. Once a session has been idle long enough (its app_close arrived, or no event for N minutes), its metrics are final. Keep a per-session accumulator and update it as events stream in:

```sql
-- session_metrics(session_id PK, user_id, first_ts, last_ts, scrolls, clicks, purchases)
-- Snowflake / ANSI MERGE (UNVERIFIED). events_batch = events not yet applied (watermark on event_id).
MERGE INTO session_metrics t
USING (
  SELECT session_id, MIN(user_id) AS user_id,
         MIN(event_timestamp) AS first_ts, MAX(event_timestamp) AS last_ts,
         COUNT_IF(event_type = 'scroll')   AS scrolls,
         COUNT_IF(event_type = 'click')    AS clicks,
         COUNT_IF(event_type = 'purchase') AS purchases
  FROM events_batch GROUP BY session_id
) s
ON t.session_id = s.session_id
WHEN MATCHED THEN UPDATE SET
  first_ts = LEAST(t.first_ts, s.first_ts), last_ts = GREATEST(t.last_ts, s.last_ts),
  scrolls = t.scrolls + s.scrolls, clicks = t.clicks + s.clicks, purchases = t.purchases + s.purchases
WHEN NOT MATCHED THEN INSERT VALUES
  (s.session_id, s.user_id, s.first_ts, s.last_ts, s.scrolls, s.clicks, s.purchases);

-- Zombies, over closed sessions only:
SELECT session_id, user_id, DATEDIFF(minute, first_ts, last_ts) AS session_duration_minutes, scrolls AS scroll_count
FROM session_metrics
WHERE last_ts < CURRENT_TIMESTAMP - INTERVAL '30 minutes'        -- session is idle: closed
  AND DATEDIFF(minute, first_ts, last_ts) > 30 AND scrolls >= 5
  AND clicks / scrolls < 0.20 AND purchases = 0;
```

Caveats that interviewers probe. *Snowflake's `DATEDIFF(minute, …)` counts minute boundaries crossed rather than truncating elapsed time*, so 08:00:59 → 08:31:00 is 31 there but 30 in MySQL. Pick one definition and test it. *Idempotency*: the additive counts need the `event_id` watermark, while `LEAST`/`GREATEST` are safe to re-apply. *Late events* for a session already reported as a zombie can un-zombie it (a late purchase). Either emit corrections, or wait for an allowed-lateness window before reporting.

## 7. Edge cases

Each "breaks" claim below is checked by execution: `mistakes/*.sql` are the tempting wrong queries, and the harness asserts that each one fails every dataset it names (`harness/test_mistakes.py`).

| Case | Dataset | Wrong queries it catches (`mistakes/`) |
|---|---|---|
| Session crossing midnight that opens/closes with app_open/app_close; a qualifying-looking session with a purchase | `tests/edge_typical.sql` | `filter_event_types_first` (dropping app_open/close shortens a1 to 25 min) |
| Ratio exactly 1/5 = 0.2000 vs 1/6 = 0.1667 | `tests/edge_ratio_boundary.sql` | `ratio_inclusive`, `clicks_over_all_events` |
| 30:59 (truncates to 30), exactly 30:00, and 31:00 (Assumptions 1–2) | `tests/edge_duration_boundary.sql` | `duration_at_least_30`, `fractional_minutes`, `more_than_5_scrolls` |
| 4 scrolls (plus open/close) vs exactly 5 scrolls; both sessions of one user | `tests/edge_scroll_boundary.sql` | `count_of_boolean` (`COUNT(cond)` counts all 6 events), `more_than_5_scrolls`, `group_by_user` |
| `event_value` NULL on scrolls and on a purchase | `tests/edge_nulls.sql` | `purchase_by_amount` (a NULL-amount purchase looks like no purchase), `more_than_5_scrolls` |
| More scrolls first, even with a later session id | `tests/edge_ordering.sql` | `more_than_5_scrolls` |
| Scroll-count tie; user ids run opposite to session ids | `tests/edge_ordering_tie.sql` | `order_by_user_on_tie`, `more_than_5_scrolls` |
| Purchase with amount 0; a 20-minute session | `tests/edge_none_qualify.sql` | `purchase_by_amount` |

No approach in `solutions/` is broken by any of these. Approach 1 is slow without an index, not wrong.

## 8. Interviewer follow-ups

1. **"Sessions aren't given: derive them as 'a gap of more than 30 minutes starts a new session'."** That is sessionization proper: `LAG(event_timestamp) OVER (PARTITION BY user_id ORDER BY event_timestamp)`, flag a new session when the gap exceeds 30 minutes, and take a running `SUM` of the flags as the session number. Then run this query grouped by (`user_id`, session number). It is the same flag-and-count idea as approach 2 of `33-find-users-with-persistent-behavior-patterns`.
2. **"Report the share of each user's sessions that are zombies."** Compute the zombie flag per session (the `HAVING` conditions moved into a `CASE` in the `SELECT`), then `AVG(is_zombie)` per user. This is two-level aggregation, as in `35-find-overbooked-employees`.
3. **"Duration should exclude idle gaps over 10 minutes."** Duration becomes the sum of consecutive gaps that are ≤ 10 minutes: `LAG` within the session, then `SUM(CASE WHEN gap <= 600 THEN gap END)`. A window has to run before the aggregate.
4. **"What if a session has no scrolls at all?"** It fails `>= 5` anyway. If the rules changed so that the ratio was tested on its own, `x / 0` is NULL in MySQL `SELECT`s (a warning under the default `ERROR_FOR_DIVISION_BY_ZERO` mode, because the mode only errors on writes), and NULL fails the comparison. Say this out loud rather than relying on it. `NULLIF(scrolls, 0)` makes the intent explicit.
5. **"Why `SUM(event_type = 'scroll')` and not `COUNT(...)`?"** `COUNT` counts non-NULL values, and FALSE (0) is non-NULL, so `COUNT(event_type = 'scroll')` equals `COUNT(*)`. Use `SUM(cond)`, `COUNT(CASE WHEN cond THEN 1 END)`, or `COUNT_IF` in Snowflake.

## 9. Snowflake notes (UNVERIFIED)

`snowflake.sql` keeps the shape of approach 3. What changes, and why:

- `COUNT_IF(event_type = 'scroll')` replaces `SUM(boolean)`, because Snowflake does not sum booleans.
- **Duration semantics differ.** Snowflake's `DATEDIFF(minute, a, b)` counts minute *boundaries crossed*, so 08:00:59 → 08:31:00 is 31 there, while MySQL's `TIMESTAMPDIFF` truncates the elapsed time to 30. To match MySQL, use `FLOOR(DATEDIFF(second, a, b) / 60)`, which is what `snowflake.sql` does.
- Integer division: `COUNT_IF(...) / COUNT_IF(...)` returns a decimal in Snowflake, as in MySQL, so the 0.20 comparison works. Other engines (Spark SQL with ANSI off, Postgres on integers) may truncate to 0, which makes every ratio "< 0.20". Cast explicitly when porting.
- No indexes. A clustering key is not useful for a full-table `GROUP BY session_id`. For date-bounded variants, cluster on `event_timestamp` and accept that sessions crossing the bound are cut.

## 10. Pattern links

Same pattern (per-entity event metrics, conditional aggregation in one pass):
- `04-monthly-transactions-i`, `05-find-loyal-customers`, `06-find-golden-hour-customers`: conditional aggregation with `HAVING` filters.
- `07-trips-and-users`: a ratio of two conditional counts, with its own denominator trap.

Related:
- `35-find-overbooked-employees`: the same "rule on a group total" shape, plus a second aggregation level.
- `33-find-users-with-persistent-behavior-patterns`: flag-and-count sessionization, for follow-up 1.
- `34-find-covid-recovery-patients`: event sequencing where order matters (here only the first and last timestamps matter).
