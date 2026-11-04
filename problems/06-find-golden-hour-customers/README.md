# 06 · Find Golden Hour Customers

## 1. Problem & trigger phrases

Original: [Find Golden Hour Customers](https://leetcode.com/problems/find-golden-hour-customers/) (LeetCode 3705, medium). Read the statement there; this guide only restates the spec in its own words.

**Spec (own words):** from a table of restaurant orders, find customers with at least 3 orders, at least 60% of them placed in the lunch or dinner window, an average rating of at least 4.0 over the orders that were rated, and at least half of their orders rated. Report each customer's order count, the peak-hour share as a whole percentage, and the average rating to 2 decimals, best rating first.

| Trigger phrase | What it forces in SQL |
|---|---|
| "at least 60% of their orders" | A share of the customer's *whole* order set: peak orders ÷ all orders, tested in `HAVING` (or on a per-customer CTE). Compare with integers: `5 * peak >= 3 * total`. |
| "11:00-14:00 or 18:00-21:00" | A **time-of-day** test on a datetime, two windows OR'd, inclusive at both ends: `TIME(ts) BETWEEN '11:00:00' AND '14:00:00' OR TIME(ts) BETWEEN '18:00:00' AND '21:00:00'`. Not `HOUR()`: that is too coarse (14:30 is hour 14). |
| "average rating for rated orders" | `AVG(order_rating)`: it ignores NULLs, which is exactly the wanted behaviour. `AVG(COALESCE(order_rating, 0))` is the classic bug. |
| "rated at least 50% of their orders" | A second share, with a different numerator: `COUNT(order_rating)` (rated orders) over `COUNT(*)`. Integer form: `2 * COUNT(order_rating) >= COUNT(*)`. |

Notice that the four criteria use **four different row sets** over the same customer: all orders (count, rated share denominator, peak share denominator), peak orders (numerator), rated orders (numerator and average). That is the decomposition problem: every one of them is an aggregate with its own condition, in one `GROUP BY`.

## 2. Schema & grain

| Table | One row means | Keys that matter here |
|---|---|---|
| `restaurant_orders` | one order | `order_id` (PK); `customer_id`; `order_timestamp` (date and time of day); `order_rating` (1-5 or NULL). `order_amount` and `payment_method` are distractors. |

**Output grain:** one row per qualifying customer, with three measures. Ordering is exact: `average_rating DESC`, then `customer_id DESC`.

**Where the grain changes:** order grain → customer grain, in one `GROUP BY customer_id`. There is also a grain change *inside* the row: the question is about a **time of day**, so each order is first reduced to a 0/1 flag ("peak or not") before it can be counted.

## Assumptions

Confidence is `medium`: the rounding of the percentage and the inclusivity of the window ends are inferred from a reference solution, not stated. Interpretations used here, each tested:

1. **Peak windows are inclusive at both ends:** 11:00:00 and 14:00:00 are peak, 14:00:01 is not; same for 18:00:00-21:00:00. Tested at the second level by `tests/edge_peak_boundaries.sql`.
2. **`peak_hour_percentage` is rounded to a whole number** (`ROUND(100 * peak / total)`), with halves rounded up (62.5 → 63). Tested by `tests/edge_rounding.sql`. The criterion itself ("at least 60%") is tested on the exact ratio, never on the rounded number.
3. **`average_rating` is `ROUND(AVG(order_rating), 2)`**, with the test `AVG(order_rating) >= 4` applied to the unrounded average. (With only 2-decimal rounding, an average of 3.996 would display as 4.00 but must not qualify; reaching such a value needs at least 200 rated orders, far more than a 15-row edge dataset can hold. The decision is by reasoning; the SQL does the right thing by construction.)
4. **The sort key is the rounded output column.** `ORDER BY average_rating DESC` uses the alias, i.e. the rounded value, with `customer_id DESC` breaking ties. Two customers whose averages round to the same value tie even if their raw averages differ. A small edge dataset cannot separate "sort by rounded" from "sort by raw": it needs two different raw averages that round alike, which takes more rows than 15 (e.g. 33/8 and 62/15 both round to 4.13). The tie-break itself is tested with customers whose averages are exactly equal (`edge_threshold_boundaries`).
5. **NULL ratings** count toward `total_orders` and toward the rated-share denominator, but not toward the average. A customer with no rated orders has a NULL average and fails both the share and the average test.
6. **All columns except `order_rating` are NOT NULL**; the timestamp has no time zone, so "11:00" means the stored clock time as is.

## 3. Hint ladder

<details><summary>Hint 1</summary>

Pattern: **conditional aggregation + filtering on aggregates** (`HAVING`), with a time-of-day flag per row.

</details>

<details><summary>Hint 2</summary>

Shape: (1) group the orders by customer. (2) Per customer compute: order count, number of peak orders, number of rated orders, average rating. (3) Keep customers where all four tests pass; format the shares and the average; sort by average (desc) then customer id (desc).

</details>

<details><summary>Hint 3</summary>

Key trick: turn "peak" into a 0/1 expression and `SUM` it (`SUM(TIME(ts) BETWEEN … OR TIME(ts) BETWEEN …)`); `COUNT(order_rating)` is the rated count and `AVG(order_rating)` already skips NULLs. Compare shares as cross-products (`5 * peak >= 3 * total`, `2 * rated >= total`) so no division or rounding can flip an exact 60% or 50%. Compute each aggregate once (in a CTE), not once in `SELECT` and again in `HAVING`.

</details>

## 4. Decomposition

Read each criterion as "which rows, aggregated how, compared to what".

1. **`per_customer`: `GROUP BY customer_id` over `restaurant_orders`.**
   *Why a GROUP BY here:* every criterion is about a customer's whole set of orders, so orders collapse to customer grain first.
2. **Four aggregates inside it, each over its own row set.**
   - `COUNT(*)` = total orders: *all* rows ("at least 3 orders", and the denominator of both shares).
   - `SUM(<peak test>)` = peak orders: *why conditional:* the numerator of the peak share is a subset of the same group, and the test is on the *time of day* of each row, so it is evaluated per row, then summed.
   - `COUNT(order_rating)` = rated orders: *why `COUNT(col)`:* it counts non-NULL ratings, which is exactly "rated".
   - `AVG(order_rating)` = average over the rated orders: *why plain `AVG`:* it already ignores NULLs; coalescing them to 0 would count unrated orders as 0-star.
3. **Filter: four predicates, `AND`ed, on the per-customer numbers.**
   *Why after grouping:* each predicate is on an aggregate. *Why cross-products:* `5 * peak >= 3 * total` is `peak / total >= 0.6` with no division, so an exact 60% can't be nudged by rounding.
4. **Project and sort.**
   *Why `ROUND(100 * peak / total)` and `ROUND(avg, 2)` here, not earlier:* rounding is presentation; the filters need the exact values. Sort by the rounded alias, then `customer_id DESC`.

```sql
WITH per_customer AS (                          -- steps 1 + 2: order grain -> customer grain
  SELECT customer_id,
         COUNT(*)                                                   AS total_orders,
         SUM(TIME(order_timestamp) BETWEEN '11:00:00' AND '14:00:00'
          OR TIME(order_timestamp) BETWEEN '18:00:00' AND '21:00:00') AS peak_orders,
         COUNT(order_rating)                                        AS rated_orders,
         AVG(order_rating)                                          AS avg_rating
  FROM restaurant_orders
  GROUP BY customer_id
)
SELECT customer_id,                             -- steps 3 + 4
       total_orders,
       ROUND(100 * peak_orders / total_orders) AS peak_hour_percentage,
       ROUND(avg_rating, 2)                    AS average_rating
FROM per_customer
WHERE total_orders >= 3
  AND 5 * peak_orders >= 3 * total_orders
  AND 2 * rated_orders >= total_orders
  AND avg_rating >= 4
ORDER BY average_rating DESC, customer_id DESC;
```

This is `solutions/03_per_customer_cte.sql`.

Self-check: remove the filter and look at the per-customer numbers of a customer you expect to fail, and say which criterion fails. Check that a customer with all-NULL ratings has NULL (not 0) average.

## 5. Approaches: brute force → optimal

### Approach 1: four correlated subqueries per customer (`solutions/01_correlated_subqueries.sql`)

```sql
SELECT customer_id, total_orders,
       ROUND(100 * peak_orders / total_orders) AS peak_hour_percentage,
       ROUND(avg_rating, 2)                    AS average_rating
FROM (
  SELECT c.customer_id,
         (SELECT COUNT(*) FROM restaurant_orders o WHERE o.customer_id = c.customer_id) AS total_orders,
         (SELECT COUNT(*) FROM restaurant_orders o WHERE o.customer_id = c.customer_id
             AND (TIME(o.order_timestamp) BETWEEN '11:00:00' AND '14:00:00'
               OR TIME(o.order_timestamp) BETWEEN '18:00:00' AND '21:00:00')) AS peak_orders,
         (SELECT COUNT(o.order_rating) FROM restaurant_orders o WHERE o.customer_id = c.customer_id) AS rated_orders,
         (SELECT AVG(o.order_rating) FROM restaurant_orders o WHERE o.customer_id = c.customer_id) AS avg_rating
  FROM (SELECT DISTINCT customer_id FROM restaurant_orders) c
) x
WHERE total_orders >= 3 AND 5 * peak_orders >= 3 * total_orders
  AND 2 * rated_orders >= total_orders AND avg_rating >= 4
ORDER BY average_rating DESC, customer_id DESC;
```

**Why it is correct:** the derived table lists each customer once; each subquery computes one measure over that customer's rows with exactly the row set its criterion names. The outer query filters and formats.

**Cost model (reasoned, plan shape checked with EXPLAIN on a sample):** four dependent subqueries run for **every** customer, whether or not they could qualify. The primary key is `order_id`, so without an index on `customer_id` each is a full scan: customers × rows × 4, quadratic. With `indexes.sql` each is a range read of one customer's entries.

### Approach 2: totals aggregate + peak aggregate, joined (`solutions/02_totals_and_peak_join.sql`)

```sql
WITH totals AS (
  SELECT customer_id, COUNT(*) AS total_orders, COUNT(order_rating) AS rated_orders, AVG(order_rating) AS avg_rating
  FROM restaurant_orders GROUP BY customer_id
), peak AS (
  SELECT customer_id, COUNT(*) AS peak_orders
  FROM restaurant_orders
  WHERE TIME(order_timestamp) BETWEEN '11:00:00' AND '14:00:00'
     OR TIME(order_timestamp) BETWEEN '18:00:00' AND '21:00:00'
  GROUP BY customer_id
)
SELECT t.customer_id, t.total_orders,
       ROUND(100 * p.peak_orders / t.total_orders) AS peak_hour_percentage,
       ROUND(t.avg_rating, 2)                      AS average_rating
FROM totals t JOIN peak p ON p.customer_id = t.customer_id
WHERE t.total_orders >= 3 AND 5 * p.peak_orders >= 3 * t.total_orders
  AND 2 * t.rated_orders >= t.total_orders AND t.avg_rating >= 4
ORDER BY average_rating DESC, t.customer_id DESC;
```

**Why it is correct:** `totals` is one row per customer, `peak` one row per customer with at least one peak order; the join is 1:1. A customer with no peak order is dropped by the inner join, which is right because 0% can't reach 60%. (A LEFT JOIN would be needed if the criterion could be satisfied by zero, e.g. "at most 10% peak".)

**Cost model (reasoned):** two passes over the table, one of them filtered, and a join of two small results. Linear. The time-of-day test runs once per row in `peak`'s `WHERE`. The price is a second scan and a join whose NULL-or-missing semantics you must think about.

### Approach 3 (optimal): one per-customer aggregation, filtered afterwards (`solutions/03_per_customer_cte.sql`)

The SQL is the assembled query in section 4.

**Why it is correct:** each aggregate sees exactly the rows its criterion names; the CTE has one row per customer; filtering and sorting happen on that small result. Integer cross-products keep the 60% and 50% thresholds exact.

**Cost model (reasoned, plan shape checked on a sample):** one scan, one aggregation with a handful of numbers of state per customer, the time-of-day test evaluated once per row, and a tiny filter and sort on the result. Naming each aggregate once matters: writing the peak `SUM(...)` in `SELECT` and again in `HAVING` can make the engine compute the time test twice per row.

**Measured** (`gen.py` data, generated by the bench workflow; the table is filled in automatically, so never type numbers here):

<!-- BENCH:06-find-golden-hour-customers -->
_Measured 2026-11-04 by the bench workflow: MySQL 8.0.46, AMD EPYC 9V74 80-Core Processor, 2 vCPU. Median of 3 runs after 1 warm-up; each statement capped at 60 s. Sizes are main-table rows from `gen.py`. Raw numbers and EXPLAIN ANALYZE: `bench/results/06-find-golden-hour-customers.json`._

**Without indexes**

| Solution | 1,000 rows | 100,000 rows | 1,000,000 rows | × slower than optimal @ 1,000,000 |
|---|---:|---:|---:|---:|
| `01_correlated_subqueries` | 116 ms | timeout >60s | timeout >60s † | > 33× |
| `02_totals_and_peak_join` | 2 ms | 114 ms | 1.86 s | 1.0× |
| `03_per_customer_cte` (optimal) | 1.71 ms | 99.4 ms | 1.84 s | 1.0× |

† not run at this size: it already timed out at a smaller size.

**With `indexes.sql`**

| Solution | 1,000 rows | 100,000 rows | 1,000,000 rows | × slower than optimal @ 1,000,000 |
|---|---:|---:|---:|---:|
| `01_correlated_subqueries` | 3.86 ms | 281 ms | 3.01 s | 4.4× |
| `02_totals_and_peak_join` | 1.68 ms | 86.9 ms | 907 ms | 1.3× |
| `03_per_customer_cte` (optimal) | 1.45 ms | 68.3 ms | 686 ms | 1.0× |

> GitHub-hosted runners are shared, noisy VMs: compare the ratios between rows, not the absolute times.
<!-- /BENCH -->

### Why the optimal one wins

Approach 3 reads the table once and evaluates each row-level expression once, so adding a criterion costs one more column in the CTE, not another scan or join. Approach 2 can be close, since its extra scan is cheap when the time test is selective, so the margin is for the bench table to show, not for the reasoning to promise. Approach 1 is the outlier: its work is per customer × per measure, on every customer including the ones that could never qualify.

## 6. At scale

**(a) What breaks first.** *Reasoned, to be checked against the bench table:* approach 1 without an index on `customer_id` (quadratic). Approach 2 and 3 are linear; the next limit is the per-row `TIME()` evaluation, which cannot use any index, and then the memory for per-customer aggregation state, which grows with distinct customers, not with orders.

**(b) One machine, ~1M–100M rows.**
- `indexes.sql` adds `(customer_id, order_timestamp, order_rating)`: covering for all three, makes approach 1 feasible, and lets the aggregation stream in customer order without a temporary table.
- **An ordinary index cannot help the time-of-day test**: it is a function of the stored datetime, not a range on it (the same hours repeat every day). A functional index on `TIME(order_timestamp)` is possible, but the windows cover a large share of the day and the query needs every order for the totals anyway, so it would not skip much. The scalable fix is to store the derived flag or hour at write time (a generated column `is_peak`), which turns a per-row function into a column read.
- Don't sort the whole table: only the final qualifying customers need `ORDER BY`.

**(c) Distributed engines, billions of rows. *Reasoned, not measured.***
- *Shuffle:* a shuffle by `customer_id`, with partial aggregates: counts and sums are decomposable. `AVG` is not mergeable as an average, but as `(sum, count)` it is; a good engine does this automatically.
- *Skew:* a few customers with huge order counts (test or corporate accounts) would hot-spot one reducer in a row-level shuffle; partial aggregation reduces each to one row per task.
- *Pruning:* with no date filter there is nothing to prune. If the question were "last month" a range on the raw timestamp prunes micro-partitions; the time-of-day test never prunes.
- *Things to avoid:* a global sort of the orders; approximate functions: the criteria have exact thresholds (exactly 60%, exactly 4.0), where an error of 1-2% from a sketch changes the answer.
- *Time zone trap:* "11:00" is the restaurant's local time. If timestamps are stored in UTC, convert before the time-of-day test, per restaurant; otherwise lunch moves by hours and by daylight saving. This query's windows are valid only in the zone the timestamps are stored in.

**(d) The data-engineering answer.** Compute the per-order flag once at ingest, and keep per-customer mergeable counters; "golden hour" becomes a read of the summary. Store the **sum** of ratings and the **count** of rated orders (not the average), so batches combine by addition:

```sql
-- customer_order_summary(customer_id PK, n_orders, n_peak, n_rated, sum_rating)
-- Snowflake / ANSI MERGE (UNVERIFIED):
MERGE INTO customer_order_summary t
USING (SELECT customer_id, COUNT(*) AS n, COUNT_IF(is_peak) AS pk, COUNT(order_rating) AS rt, SUM(order_rating) AS sr
       FROM orders_batch                 -- only rows not yet applied (watermark on order_id); is_peak set at ingest
       GROUP BY customer_id) s
ON t.customer_id = s.customer_id
WHEN MATCHED THEN UPDATE SET n_orders = t.n_orders + s.n, n_peak = t.n_peak + s.pk,
                             n_rated = t.n_rated + s.rt, sum_rating = COALESCE(t.sum_rating, 0) + COALESCE(s.sr, 0)
WHEN NOT MATCHED THEN INSERT (customer_id, n_orders, n_peak, n_rated, sum_rating) VALUES (s.customer_id, s.n, s.pk, s.rt, s.sr);

-- MySQL equivalent (no MERGE):
INSERT INTO customer_order_summary (customer_id, n_orders, n_peak, n_rated, sum_rating)
SELECT customer_id, COUNT(*), SUM(is_peak), COUNT(order_rating), SUM(order_rating) FROM orders_batch GROUP BY customer_id
ON DUPLICATE KEY UPDATE n_orders = n_orders + VALUES(n_orders), n_peak = n_peak + VALUES(n_peak),
                        n_rated = n_rated + VALUES(n_rated),
                        sum_rating = COALESCE(sum_rating, 0) + COALESCE(VALUES(sum_rating), 0);

-- The question reads only the summary:
SELECT customer_id, n_orders AS total_orders, ROUND(100 * n_peak / n_orders) AS peak_hour_percentage,
       ROUND(sum_rating / n_rated, 2) AS average_rating
FROM customer_order_summary
WHERE n_orders >= 3 AND 5 * n_peak >= 3 * n_orders AND 2 * n_rated >= n_orders AND sum_rating / n_rated >= 4
ORDER BY average_rating DESC, customer_id DESC;
```

Caveats interviewers probe. *Idempotency:* re-applying a batch double-counts, so track the applied watermark. *Late ratings:* a rating that arrives after the order is an update (NULL → value), not an insert, so the delta is `+1` rated and `+value` on the sum, needing a change feed. *Qualification is not monotonic:* a new unrated order can drop a customer below 50% rated, so qualification is always derived from the current counters. Division by zero: `n_rated = 0` must be guarded (`NULLIF(n_rated, 0)`).

## 7. Edge cases

Each "breaks" claim below is checked by execution: `mistakes/*.sql` are the tempting wrong queries, and the harness asserts each one fails every dataset it names.

| Case | Dataset | Wrong queries it catches (`mistakes/`) |
|---|---|---|
| Customers failing exactly one criterion each (count, peak share, average); average of exactly 4.00 qualifies | `tests/edge_typical.sql` | `coalesce_rating_to_zero`, `average_strictly_greater`, `average_ascending` |
| Peak-window endpoints (11:00:00, 14:00:00, 18:00:00, 21:00:00 inclusive; one second outside excluded) | `tests/edge_peak_boundaries.sql` | `hour_only` (accepts 14:00:01 and 21:00:01), `exclusive_window_ends` |
| Exactly 3 orders; exactly 60% peak; exactly 50% rated; exactly 4.0 average | `tests/edge_threshold_boundaries.sql` | `orders_more_than_three`, `peak_share_strictly_greater`, `rated_share_strictly_greater`, `average_strictly_greater` |
| Rating tie: same average, order by `customer_id` DESC | `tests/edge_threshold_boundaries.sql` | `tie_break_ascending`, `average_ascending` |
| NULL ratings: counted in total, skipped in the average; all-NULL customer | `tests/edge_null_ratings.sql` | `coalesce_rating_to_zero`, `count_rating_as_total` |
| Rounding: 66.67 → 67, 62.5 → 63 (half up), 4.125 → 4.13, 4.3333 → 4.33; order by the rounded average | `tests/edge_rounding.sql` | `double_arithmetic` (DOUBLE rounds the exact halves to even: 62 and 4.12), `average_ascending` |
| Empty table | `tests/edge_empty.sql` | none: an empty result |
| Rounded average could cross 4.0 (3.996 → 4.00) | not testable in 15 rows | handled by construction: the filter uses the unrounded `AVG` (assumption 3) |

No approach in `solutions/` is broken by any of these. Approach 1 is slow without an index, not wrong.

## 8. Interviewer follow-ups

1. **"Why compare `5 * peak >= 3 * total` instead of `peak / total >= 0.6`?"** They are equal on paper. The integer form has no division, so engines that round quotients to a fixed number of decimals, or use floating point, cannot push an exact 60% either way. It also states the threshold as a ratio of whole numbers.
2. **"What if the windows were stored in a table?"** Join each order to the window table on `TIME(ts) BETWEEN start AND end` and `COUNT(DISTINCT order_id)` (an order must not be double-counted if windows overlap). That changes the flag from an expression to a semi-join: `EXISTS (SELECT 1 FROM windows w WHERE TIME(o.ts) BETWEEN w.start_time AND w.end_time)`.
3. **"Why not `HOUR(order_timestamp) BETWEEN 11 AND 14`?"** It accepts 14:00:01 to 14:59:59. If the intent was "11:00 up to and including 14:00:00", `HOUR` can't say it. Use `TIME()` with explicit endpoints, or a half-open `>= 11:00:00 AND < 14:00:00` if the spec's window were half-open.
4. **"Add 'rated orders only' to the peak share."** The denominator for the peak share changes from `COUNT(*)` to `COUNT(order_rating)`, and the numerator to peak *and* rated orders: `SUM(is_peak AND order_rating IS NOT NULL)`. Say which share the sentence means before writing SQL.
5. **"A customer's rating is NULL because the app crashed. Should that count as unrated?"** It is a data-quality question: the spec's "rated" is `order_rating IS NOT NULL`. If crashes should be excluded from the denominator, you need a reason column; without one, the SQL can't tell the difference.

## 9. Snowflake notes (UNVERIFIED)

`snowflake.sql` keeps the shape of approach 3. What changes:

- `COUNT_IF(cond)` replaces `SUM(cond)` (booleans cannot be summed directly).
- `TO_TIME(order_timestamp)` replaces `TIME(order_timestamp)`; comparing a TIME to string literals like `'11:00:00'` relies on implicit conversion, so it is worth writing `'11:00:00'::TIME` explicitly. I couldn't run it.
- `ROUND(x, 0)`: Snowflake's `ROUND` with one argument also rounds to an integer; both round halves away from zero on `NUMBER`, so the 62.5 → 63 case should match MySQL's DECIMAL behaviour. If the expression were floating point (`FLOAT`), tie behaviour can differ; check.
- `AVG` ignores NULLs the same way; the average of an all-NULL group is NULL.
- Aliases are usable in `ORDER BY` and in later CTE steps; the CTE may be inlined by the optimizer, so naming an expression once is about clarity and correctness, not a guaranteed saving.
- No secondary indexes; clustering by `customer_id` keeps each customer's rows together, which helps the aggregation; the time-of-day test never prunes. Unquoted identifiers come back upper-cased.

## 10. Pattern links

Same pattern (conditional aggregation, shares and averages per group, filtered in HAVING):
- `05-find-loyal-customers`: the closest sibling: per-customer counts, a date span, and a refund share.
- `04-monthly-transactions-i`: the same one-pass conditional aggregates grouped by (month, country).
- `02-confirmation-rate`: a conditional share per user with a zero case.
- `07-trips-and-users`: a conditional ratio per day.
- `24-immediate-food-delivery-ii`: a conditional share over a derived subset.

Time-of-day / bucketing relatives:
- `35-find-overbooked-employees`, `17-seasonal-sales-analysis`: bucketing timestamps (week, season) before aggregating.
