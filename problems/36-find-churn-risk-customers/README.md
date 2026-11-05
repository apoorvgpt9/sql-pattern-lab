# 36 · Find Churn Risk Customers

## 1. Problem & trigger phrases

Original: [Find Churn Risk Customers](https://leetcode.com/problems/find-churn-risk-customers/) (LeetCode 3716, medium). Read the statement there; this guide only restates the spec in its own words.

**Spec (own words):** a user is *at risk* when four things are true at once:
1. their most recent event is not a cancel;
2. they have downgraded at least once;
3. what they pay now (the amount on the most recent event) is less than half of the most they ever paid;
4. their first and last events are at least 60 days apart.

Report the current plan and amount, the historical maximum, and the day span. Longest span first, then by user id. "Most recent" means latest `event_date`, and on a tie the higher `event_id`.

| Trigger phrase | What it forces in SQL |
|---|---|
| "their last event is not cancel" | One specific row per user: the latest. That is `ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY event_date DESC, event_id DESC) = 1`. A join back on `MAX(event_date)` returns *every* event of the last day. It is a condition on that row only: a cancel earlier in history does not matter. |
| "at least one downgrade" | A fact about the **whole history**, not the latest row: `SUM(event_type = 'downgrade') >= 1` (or `EXISTS`). |
| "less than 50% of … historical maximum" | Mixes the two grains: the latest row's `monthly_amount` against `MAX(monthly_amount)` over all rows. Strict `<`. |
| "subscriber for at least 60 days" | `DATEDIFF(MAX(event_date), MIN(event_date)) >= 60`, a history fact, measured between events and not up to today. `>=`. |

## 2. Schema & grain

| Table | One row means | Keys that matter here |
|---|---|---|
| `subscription_events` | one subscription event | `event_id` (PK, also the same-day tiebreak), `user_id`, `event_date`, `event_type`, `plan_name` (NULL on cancel), `monthly_amount` (0 on cancel) |

**Output grain:** one row per at-risk user.

**Where the grain changes:** this is the defining feature of the problem. The answer needs facts at **two different grains**, both collapsing to one row per user:

- **the latest row** (a row-level pick): `event_type`, `plan_name`, `monthly_amount`, `event_date`;
- **history aggregates** (a group-level summary): `MAX(monthly_amount)`, `MIN(event_date)`, the downgrade count.

You can't get both from one plain `GROUP BY user_id`: the group gives you `MAX`, but not "the plan on the latest row". So you either compute them separately and join them 1:1 on `user_id` (approach 3), or compute the aggregates as windows so they sit on every row and then keep the latest row (approach 2). Each condition in the spec belongs to exactly one of the two grains. Sorting them out first is the decomposition.

| Condition | Grain |
|---|---|
| latest event not cancel | latest row |
| ≥ 1 downgrade | history |
| current < 0.5 × max | latest row vs history |
| span ≥ 60 days | history (and `MAX(event_date)` is the latest row's date) |

## 3. Hint ladder

<details><summary>Hint 1</summary>

Pattern: **latest record per key** combined with **whole-history aggregates** for the same key.

</details>

<details><summary>Hint 2</summary>

Shape: (1) pick each user's latest event, with a deterministic tiebreak. (2) Separately, summarise each user's full history: maximum amount, first and last dates, number of downgrades. (3) Put the two together per user and apply the four conditions. (4) Sort.

</details>

<details><summary>Hint 3</summary>

Key trick: `ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY event_date DESC, event_id DESC)` picks exactly one latest row even when two events share a date (the `event_id DESC` tiebreak is what makes it deterministic). The history summary is a plain `GROUP BY user_id` with `MAX`, `MIN` and `SUM(event_type = 'downgrade')`. Join them on `user_id` with `rn = 1`, and both sides are exactly one row per user.

</details>

## 4. Decomposition

Sort the four conditions by grain *before* writing SQL (the table in section 2). Every phrase with "last", "current" or "most recent" points to one row. Every phrase with "at least one", "maximum" or "for N days" points to the history.

1. **`ranked`: `ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY event_date DESC, event_id DESC) AS rn`.**
   *Why a window here:* "most recent event" is a position in an order, and you need that row's other columns (plan, amount, type), not just its date. `event_id DESC` is the tiebreak from `rules.ties`. Without it, two events on the last day make `rn = 1` arbitrary.
2. **`history`: `GROUP BY user_id` with `MAX(monthly_amount)`, `DATEDIFF(MAX(event_date), MIN(event_date))`, `SUM(event_type = 'downgrade')`.**
   *Why a GROUP BY here:* each of these is one number per user over all events. A plain aggregate computes each one once per user. `SUM(boolean)` counts downgrades because MySQL treats `TRUE` as 1.
3. **Final: `ranked JOIN history USING user_id WHERE rn = 1 AND …four conditions…`.**
   *Why a JOIN here:* the conditions compare the two grains (current amount against the history max), so they have to meet on one row. Both sides have exactly one row per user after `rn = 1`, so the join is 1:1. *Why `WHERE` and not `HAVING`:* after the join, everything is a plain column.
4. **`ORDER BY days_as_subscriber DESC, user_id`.** One row per user, so no ties remain.

```sql
WITH ranked AS (                                  -- step 1: latest event per user
  SELECT user_id, event_type, plan_name, monthly_amount,
         ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY event_date DESC, event_id DESC) AS rn
  FROM subscription_events
),
history AS (                                      -- step 2: whole-history facts per user
  SELECT user_id,
         MAX(monthly_amount)                        AS max_amount,
         DATEDIFF(MAX(event_date), MIN(event_date)) AS days_span,
         SUM(event_type = 'downgrade')              AS n_downgrades
  FROM subscription_events
  GROUP BY user_id
)
SELECT r.user_id,                                 -- step 3: both grains meet, 1:1
       r.plan_name      AS current_plan,
       r.monthly_amount AS current_monthly_amount,
       h.max_amount     AS max_historical_amount,
       h.days_span      AS days_as_subscriber
FROM ranked r
JOIN history h ON h.user_id = r.user_id
WHERE r.rn = 1
  AND r.event_type <> 'cancel'                    -- latest row
  AND h.n_downgrades >= 1                         -- history
  AND r.monthly_amount < 0.5 * h.max_amount       -- latest vs history
  AND h.days_span >= 60                           -- history
ORDER BY days_as_subscriber DESC, r.user_id;      -- step 4
```

Arithmetic check: `0.5 * 30.00` is the exact decimal `15.000` in MySQL, so `15.00 < 15.000` is false. That is why exactly-half is out (`tests/edge_boundary_half.sql`), with no floating-point fuzz.

## 5. Approaches: brute force → optimal

### Approach 1: correlated latest row + correlated checks (`solutions/01_correlated_latest.sql`)

```sql
WITH latest AS (
  SELECT e.* FROM subscription_events e
  WHERE e.event_id = (SELECT x.event_id FROM subscription_events x
                       WHERE x.user_id = e.user_id
                       ORDER BY x.event_date DESC, x.event_id DESC LIMIT 1)
),
checked AS (
  SELECT l.*,
         (SELECT MAX(h.monthly_amount) FROM subscription_events h WHERE h.user_id = l.user_id) AS max_amount,
         DATEDIFF(l.event_date, (SELECT MIN(f.event_date) FROM subscription_events f
                                  WHERE f.user_id = l.user_id)) AS days_span,
         EXISTS (SELECT 1 FROM subscription_events d
                  WHERE d.user_id = l.user_id AND d.event_type = 'downgrade') AS has_downgrade
  FROM latest l
)
SELECT user_id, plan_name AS current_plan, monthly_amount AS current_monthly_amount,
       max_amount AS max_historical_amount, days_span AS days_as_subscriber
FROM checked
WHERE event_type <> 'cancel' AND has_downgrade
  AND monthly_amount < 0.5 * max_amount AND days_span >= 60
ORDER BY days_as_subscriber DESC, user_id;
```

**Why it is correct:** the `LIMIT 1` subquery returns exactly one `event_id` per user (event ids are unique, and the tiebreak makes the order total), so `latest` has one row per user. Every other condition is its own lookup over the user's history. The latest row's date is the user's maximum date, so `DATEDIFF(l.event_date, MIN)` is the span.

**Cost model (reasoned from EXPLAIN):** the `latest` filter runs a dependent subquery **for every event row**, and without an index each run is `Table scan on x` plus a sort limited to one row. That is events × events. The three history subqueries add a full scan each per latest row. With `indexes.sql`, each becomes a `Covering index lookup … (user_id=e.user_id)` over a handful of entries, and the total turns roughly linear. Even then, the plan still touches each user's events about five times.

### Approach 2: one window pass (`solutions/02_one_window_pass.sql`)

```sql
WITH per_event AS (
  SELECT user_id, event_date, event_type, plan_name, monthly_amount,
         ROW_NUMBER()                  OVER w     AS rn,
         MAX(monthly_amount)           OVER w_all AS max_amount,
         MIN(event_date)               OVER w_all AS first_date,
         SUM(event_type = 'downgrade') OVER w_all AS n_downgrades
  FROM subscription_events
  WINDOW w     AS (PARTITION BY user_id ORDER BY event_date DESC, event_id DESC),
         w_all AS (w ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING)
)
SELECT user_id, plan_name AS current_plan, monthly_amount AS current_monthly_amount,
       max_amount AS max_historical_amount, DATEDIFF(event_date, first_date) AS days_as_subscriber
FROM per_event
WHERE rn = 1 AND event_type <> 'cancel' AND n_downgrades >= 1
  AND monthly_amount < 0.5 * max_amount AND DATEDIFF(event_date, first_date) >= 60
ORDER BY days_as_subscriber DESC, user_id;
```

**Why it is correct:** all four window columns share one partition and order. `w_all` reuses `w`'s ordering and widens the frame to the whole partition, so `MAX`, `MIN` and `SUM` see the full history on every row. Without that explicit frame, an ordered window defaults to "from the start of the partition up to the current row". In descending date order, the latest row (`rn = 1`) would then see only itself. The `rn = 1` row is the latest event, and it carries the history values with it.

**Cost model (reasoned from EXPLAIN):** one scan and one sort (`Sort: user_id, event_date DESC, event_id DESC`), then `Window aggregate with buffering` for the three framed aggregates. "With buffering" means MySQL holds each partition and evaluates the frame for **every row**. So all three aggregates are computed once per *event*, and then every row except one per user is discarded. It needs no join and no second scan, but it does about (events ÷ users) times more aggregate work than a `GROUP BY`. On MySQL that is usually the more expensive trade: compare with approach 3 in the bench table.

### Approach 3 (optimal): latest row JOIN history aggregates (`solutions/03_latest_join_aggregates.sql`)

The SQL is the assembled query in section 4.

**Why it is correct:** `ranked` with `rn = 1` is exactly one row per user, the latest by (date, id). `history` is exactly one row per user. The 1:1 join puts the two grains side by side, and each condition reads the side it belongs to.

**Cost model (reasoned from EXPLAIN):** two scans of `subscription_events`. The first is sorted once for `ROW_NUMBER()`, the only fact that needs order. The second is an `Aggregate using temporary table` (hash-style) that computes each history fact once per user. The two meet through `Index lookup on h using <auto_key0>`. With `indexes.sql`, the history pass becomes a streaming `Group aggregate` over the index, with no temporary table. The ranking pass still sorts.

**Measured** (`gen.py` data, generated by the bench workflow; the table is filled in automatically, so never type numbers here):

<!-- BENCH:36-find-churn-risk-customers -->
_Measured 2026-11-04 by the bench workflow: MySQL 8.0.46, INTEL(R) XEON(R) PLATINUM 8573C, 2 vCPU. Median of 3 runs after 1 warm-up; each statement capped at 60 s. Sizes are main-table rows from `gen.py`. Raw numbers and EXPLAIN ANALYZE: `bench/results/36-find-churn-risk-customers.json`._

**Without indexes**

| Solution | 1,000 rows | 100,000 rows | 1,000,000 rows | × slower than optimal @ 1,000,000 |
|---|---:|---:|---:|---:|
| `01_correlated_latest` | 169 ms | timeout >60s | timeout >60s † | > 23× |
| `02_one_window_pass` | 3.85 ms | 556 ms | 7.38 s | 2.9× |
| `03_latest_join_aggregates` (optimal) | 2.02 ms | 153 ms | 2.57 s | 1.0× |

† not run at this size: it already timed out at a smaller size.

**With `indexes.sql`**

| Solution | 1,000 rows | 100,000 rows | 1,000,000 rows | × slower than optimal @ 1,000,000 |
|---|---:|---:|---:|---:|
| `01_correlated_latest` | 6.89 ms | 508 ms | 8.12 s | 2.1× |
| `02_one_window_pass` | 3.83 ms | 558 ms | 7.34 s | 1.9× |
| `03_latest_join_aggregates` (optimal) | 2.42 ms | 184 ms | 3.82 s | 1.0× |

> GitHub-hosted runners are shared, noisy VMs: compare the ratios between rows, not the absolute times.
<!-- /BENCH -->

### Why the optimal one wins

Each fact is computed at its natural grain: one sort for the only thing that needs order, and one aggregation that computes each history value once per user. Approach 2 looks leaner on paper (one scan, no join), but it computes every history value once per *row* and throws almost all of them away, and MySQL's buffered window frames are not cheap. "Fewer passes" is not the same as "less work". The join is 1:1 and probes an auto-key, so it is not the expensive part. Approach 1 is correct but touches each user's history several times, and without the index it is quadratic. Measured at 1M rows without indexes: approach 3 took 2.57 s and approach 2 7.38 s (2.9× slower); approach 1 timed out at 100K.

## 6. At scale

**(a) What breaks first.** *Reasoned, then checked by the bench table:* approach 1 without the index. Its `latest` filter alone is a dependent subquery per event row. Approach 2 next, as the buffered partitions and per-row frame evaluation grow with history length (heavy users hurt most). Approach 3's sort and hash aggregate degrade last.

**(b) One machine, ~1M–100M rows.**
- `indexes.sql` adds `(user_id, event_date, event_id)`, the exact "latest per user" order. It rescues approach 1 (from a timeout at 100K rows to 8.1 s at 1M). For approach 3 it backfired: the bench measured it **slower** with the index (2.57 s → 3.82 s at 1M). The bench's `EXPLAIN ANALYZE` shows why. MySQL switches the `history` aggregate from a hash aggregate over a table scan (~1.1 s) to a streaming `Group aggregate` in index order (~2.2 s), but the index does not contain `event_type` or `monthly_amount`, so every row in index order costs a primary-key lookup. Making the index covering, `(user_id, event_date, event_id, event_type, monthly_amount)`, would remove those lookups (reasoned, not benchmarked). MySQL 8.0 still sorts for the window functions even with the index (EXPLAIN keeps the `Sort`), so the ranking pass does not get cheaper either.
- To make "latest event" itself index-driven, replace the window with a per-user lookup: `JOIN LATERAL (SELECT … FROM subscription_events x WHERE x.user_id = u.user_id ORDER BY event_date DESC, event_id DESC LIMIT 1)` from a distinct-users list. With the index, each lookup reads one entry backwards. This is reasoned. It wins when users have long histories and loses when most users have one or two events.
- Every condition can be computed in one streaming pass over the index in ascending order, if "latest" is detected as "the next row belongs to another user". That is `LEAD(event_id) OVER w IS NULL` with running aggregates over `ROWS UNBOUNDED PRECEDING`. It is a valid formulation, but it still evaluates four window columns for every row and then discards all but one row per user, the same waste as approach 2. Expect it to cost about what approach 2 costs, not less (reasoned; it is not one of the benchmarked solutions).

**(c) Distributed engines, billions of rows. *Reasoned, not measured.***
- *Shuffle:* everything is keyed by `user_id`. A Spark-style plan for approach 3 shuffles twice by `user_id` (once for the window, once for the aggregate) unless the planner reuses the exchange. Partitioning the table by `user_id` up front (bucketing or `repartition`) makes both passes and the join local. Approach 2 needs exactly one shuffle plus a sort within each partition, so it is the one that suits a distributed engine better. The MySQL-specific cost of buffered frames does not carry over.
- *Pre-aggregation:* the history facts (`MAX`, `MIN`, `SUM`) are decomposable, so map-side partial aggregation shrinks the shuffle. The "latest row" can be decomposed too: keep the max of (event_date, event_id, plan, amount, type) as a struct. Snowflake's `MAX_BY` and Spark's `max_by` do exactly that, and they turn approach 3 into **one** `GROUP BY` with no window at all (section 9).
- *Skew:* a few users with thousands of events become a giant window partition in approach 2. `MAX_BY` in a `GROUP BY` handles skew better, because partial aggregation runs before the shuffle.

**(d) The data-engineering answer.** Every input is a running fold: latest event, running max, first date, downgrade count. That makes this an ideal incrementally maintained per-user state table:

```sql
-- user_sub_state(user_id PK, last_date, last_type, last_plan, last_amount,
--                max_amount, first_date, n_downgrades)
-- Snowflake / ANSI MERGE (UNVERIFIED). events_batch = events not yet applied (watermark on event_id).
MERGE INTO user_sub_state t
USING (
  SELECT user_id,
         MAX(event_date)                                                    AS b_last_date,
         MAX_BY(event_type,     event_date || '|' || LPAD(event_id, 12, '0')) AS b_last_type,
         MAX_BY(plan_name,      event_date || '|' || LPAD(event_id, 12, '0')) AS b_last_plan,
         MAX_BY(monthly_amount, event_date || '|' || LPAD(event_id, 12, '0')) AS b_last_amount,
         MAX(monthly_amount) AS b_max, MIN(event_date) AS b_first,
         COUNT_IF(event_type = 'downgrade') AS b_downgrades
  FROM events_batch GROUP BY user_id
) s
ON t.user_id = s.user_id
WHEN MATCHED THEN UPDATE SET
  max_amount   = GREATEST(t.max_amount, s.b_max),
  first_date   = LEAST(t.first_date, s.b_first),
  n_downgrades = t.n_downgrades + s.b_downgrades,
  last_type    = IFF(s.b_last_date >= t.last_date, s.b_last_type,   t.last_type),
  last_plan    = IFF(s.b_last_date >= t.last_date, s.b_last_plan,   t.last_plan),
  last_amount  = IFF(s.b_last_date >= t.last_date, s.b_last_amount, t.last_amount),
  last_date    = GREATEST(t.last_date, s.b_last_date)
WHEN NOT MATCHED THEN INSERT VALUES
  (s.user_id, s.b_last_date, s.b_last_type, s.b_last_plan, s.b_last_amount,
   s.b_max, s.b_first, s.b_downgrades);
-- The question becomes a filter on a one-row-per-user table:
-- WHERE last_type <> 'cancel' AND n_downgrades >= 1 AND last_amount < 0.5 * max_amount
--   AND DATEDIFF(day, first_date, last_date) >= 60
```

Caveats that interviewers probe. *Idempotency*: `GREATEST`/`LEAST` are idempotent, but `n_downgrades + b_downgrades` is not, so the `event_id` watermark is mandatory. *Same-day order across batches*: the `>=` on dates assumes a later batch never carries an older same-day event. A strict comparison on (date, event_id) is safer, and the sketch keeps it short at the cost of that corner. *Deletes or corrections* to old events can lower the max, which no fold can undo, so recompute the user from history.

## 7. Edge cases

Each "breaks" claim below is checked by execution: `mistakes/*.sql` are the tempting wrong queries, and the harness asserts that each one fails every dataset it names (`harness/test_mistakes.py`).

| Case | Dataset | Wrong queries it catches (`mistakes/`) |
|---|---|---|
| Two qualifying users; one with an earlier low amount but a higher current one; one whose latest is a cancel; one whose latest is an upgrade after a downgrade | `tests/edge_typical.sql` | `no_cancel_check`, `lowest_amount_not_current`, `latest_must_be_downgrade` |
| Two events on the last day: the higher `event_id` is the latest | `tests/edge_same_day_latest.sql` | `latest_by_max_date_join_back`: keeps both last-day rows, and the earlier one passes the filters |
| Span of exactly 60 (2024, leap) vs 59 days (2023) | `tests/edge_boundary_60_days.sql` | `more_than_60_days` |
| Current amount exactly half (15.00 of 30.00) vs 14.99 | `tests/edge_boundary_half.sql` | `half_inclusive` |
| Cancel in the middle (NULL `plan_name`, amount 0) followed by a restart; a cheaper restart without any downgrade | `tests/edge_restart_and_no_downgrade.sql` | `never_cancelled`, `no_downgrade_check` |
| Tie on span; rows inserted out of order | `tests/edge_ordering.sql` | none reliably; every approach sorts explicitly |
| Each user fails exactly one rule | `tests/edge_none_qualify.sql` | `no_cancel_check` |

NULLs appear only on cancel rows (`plan_name`), and a qualifying user's latest row is never a cancel, so `current_plan` is never NULL in the output. A NULL `plan_name` in mid-history is harmless, because no rule reads it (`tests/edge_restart_and_no_downgrade.sql`). One trap that no dataset can reliably catch: `ROW_NUMBER() … ORDER BY event_date DESC` *without* `event_id DESC`. On a same-day tie MySQL may return either row, so the query can pass every test and still be wrong.

## 8. Interviewer follow-ups

1. **"Use 'today' instead of the last event for tenure."** Replace `MAX(event_date)` with `CURRENT_DATE`. This makes the result non-deterministic over time, and tests then need a fixed "as of" date parameter. Say so before writing it.
2. **"Only count downgrades in the last 90 days."** That is a filtered history aggregate: `SUM(event_type = 'downgrade' AND event_date >= last_date - INTERVAL 90 DAY)`. It depends on the user's own last date, so compute `last_date` first (it is already in `history`).
3. **"Report the plan they downgraded from most recently."** Another latest-row pick, but over downgrade events and one row *before* them: `LAG(plan_name) OVER (PARTITION BY user_id ORDER BY event_date, event_id)` on the downgrade row, then the latest such row.
4. **"Why not `MAX(event_date)` and join back?"** Two events can share the last date, and the join returns both. The filters then pick whichever row passes, which is the wrong row (`mistakes/latest_by_max_date_join_back.sql`). `ROW_NUMBER` with a full tiebreak is the safe idiom.
5. **"Can you do it with one GROUP BY?"** In Snowflake or Spark, yes: `MAX_BY(plan_name, (event_date, event_id))`-style arguments pick the latest row's values inside the aggregate. In MySQL there is no `MAX_BY`. The workaround, `SUBSTRING_INDEX(GROUP_CONCAT(plan_name ORDER BY event_date DESC, event_id DESC), ',', 1)`, is fragile (string conversion, `group_concat_max_len`), so prefer approach 3.

## 9. Snowflake notes (UNVERIFIED)

`snowflake.sql` uses **one `GROUP BY`** instead of approach 3's window + join, because Snowflake has `MAX_BY`. What changes, and why:

- `MAX_BY(col, key)` returns `col` from the row with the largest `key`. The latest row is decided by (event_date, event_id), so the key has to encode both. The sketch uses `event_date || '|' || LPAD(event_id, 12, '0')`, a string that sorts correctly as long as ids fit in 12 digits. An alternative is `DATEDIFF(day, '1970-01-01', event_date) * 1e12 + event_id`.
- `COUNT_IF(event_type = 'downgrade')` replaces `SUM(boolean)`, which Snowflake does not accept on a boolean.
- `DATEDIFF(day, MIN(event_date), MAX(event_date))`: the argument order is the reverse of MySQL's.
- The result is a single aggregation with partial (map-side) aggregation and no sort. On a distributed engine that should be cheaper than either window approach (reasoned, section 6c).
- `QUALIFY ROW_NUMBER() … = 1` would be the direct port of the window approach if `MAX_BY` were not available.

## 10. Pattern links

Same pattern (latest record per key):
- `20-product-sales-analysis-iii`, `21-product-price-at-a-given-date`, `22-find-students-who-improved`: first/latest row per key, with and without tie handling.

Related:
- `34-find-covid-recovery-patients`: two facts per entity at different grains, combined with a 1:1 join.
- `23-game-play-analysis-iv`, `24-immediate-food-delivery-ii`: first-event-per-key cohorts, where `MIN(date)` plus a join back is safe only because a tiebreak exists.
- `33-find-users-with-persistent-behavior-patterns`: `ROW_NUMBER() … = 1` with an explicit tie rule.
