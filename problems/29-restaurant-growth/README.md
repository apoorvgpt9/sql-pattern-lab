# 29 · Restaurant Growth

## 1. Problem & trigger phrases

Original: [Restaurant Growth](https://leetcode.com/problems/restaurant-growth/) (LeetCode 1321, medium). Read the statement there; this guide only restates the spec in its own words.

**Spec (own words):** first add up all customers' payments per day. Then, for every day that has six earlier days of data (so from the 7th day on), report that day's 7-day total (the day and the six days before it) and that total divided by 7, rounded to two decimals. Sort by date.

| Trigger phrase | What it forces in SQL |
|---|---|
| "current day + 6 days before" | A trailing window of 7 days: `SUM(...) OVER (ORDER BY visited_on ROWS BETWEEN 6 PRECEDING AND CURRENT ROW)`, or a calendar range (`RANGE ... INTERVAL 6 DAY PRECEDING`), or a self-join on a date range. The window runs over **daily totals**, not over raw customer rows. |
| "at least one customer every day" | The guarantee that makes "6 rows before" equal "6 days before". Without it a `ROWS` window silently spans more than 7 calendar days (see Assumptions). |
| "rounded to two decimal places" | `ROUND(total / 7, 2)`. The divisor is the window size, 7, not a row count. In MySQL integer division yields extra decimals (`720/7 = 102.8571`), and `ROUND` is what gets you to two. |

Also notice: nothing here asks for per-customer output. The `Customer` table is the input; the grain you work at after the first step is *one row per date*.

## 2. Schema & grain

| Table | One row means | Keys that matter here |
|---|---|---|
| `Customer` | one customer's visit on one day | `(customer_id, visited_on)` is the PK, so several rows (customers) share a `visited_on`; `amount` is what gets summed |

**Output grain:** one row per date, starting with the 7th distinct date.

**Where the grain changes (twice):**
1. *Visits → days.* `GROUP BY visited_on` with `SUM(amount)`. This must happen **before** the window, otherwise "6 rows before" counts customer visits instead of days, and a busy day takes several rows of the window.
2. *Days → output days.* The window keeps the day grain (one row per date, with a window total added). The first six days are then cut, because they do not have six earlier days.

## Assumptions

`confidence` is `high`, and the spec relies on one guarantee that is easy to forget:

1. **No date gaps.** Every day between the first and last date has at least one customer. Under it, "the 7th distinct day" is the same as "6 days after the first date", and "6 rows before" is the same as "6 days before". The generator (`gen.py`) and all edge datasets respect this.
2. **What happens without it:** the three approaches no longer agree. In a quick manual trial with one missing date in the middle, approach 1 returned only the complete 7-day windows, approach 2 divided the shorter calendar window by 7 (counting the missing day as 0), and approach 3 slid a 7-**row** window that spanned 8 calendar days. The spec excludes this case, so it is not in the edge datasets; the point is that each approach silently encodes a different answer. In a real pipeline, produce a calendar first (see `30-calculate-a-rolling-average-of-total-revenue`).
3. **"Average" is total / 7**, not an average over rows. For complete windows this equals the average of the seven daily totals.

## 3. Hint ladder

<details><summary>Hint 1</summary>

Pattern: **pre-aggregate, then moving window**. Collapse to one row per day first, then slide a 7-day frame over the daily totals.

</details>

<details><summary>Hint 2</summary>

Shape: (1) total per day. (2) For each day, the sum of that day and the six before it. (3) Drop the first six days, which don't have a full window. (4) Divide by 7, round to 2 decimals, sort by date.

</details>

<details><summary>Hint 3</summary>

Key trick: do the daily `GROUP BY` first, then `SUM(day_total) OVER (ORDER BY visited_on ROWS BETWEEN 6 PRECEDING AND CURRENT ROW)`. A window frame cannot filter rows, so keep the days with `ROW_NUMBER() >= 7` (or `visited_on >= MIN(visited_on) + 6 days`) in an outer query. The `amount` column is the window total; the average is that total divided by 7.

</details>

## 4. Decomposition

Read the wording in the order the data has to be reshaped: *days*, then *windows over days*, then *which days to show*.

1. **`daily`: `GROUP BY visited_on`, `SUM(amount)`.**
   *Why a GROUP BY here:* the spec's first sentence ("total amount per day") changes the grain from customer visits to days. Many customers share a day, and a window over raw rows would treat each visit as its own step.
2. **`windowed`: `SUM(day_total) OVER (ORDER BY visited_on ROWS BETWEEN 6 PRECEDING AND CURRENT ROW)` plus `ROW_NUMBER() OVER (ORDER BY visited_on)`.**
   *Why a window here:* each output value depends on the neighbouring days, and every day stays in the result, so it is a moving aggregate and not a `GROUP BY`. `ROWS` is right because there is exactly one row per day and no gaps. `ROW_NUMBER` records which day this is.
3. **Keep `day_no >= 7`.**
   *Why a filter here:* the first six days have fewer than six earlier days. A window function cannot remove its own partial frames, so an outer `WHERE` does it.
4. **`ROUND(amount / 7, 2)` and `ORDER BY visited_on`.**
   *Why here:* the divisor is the window length. The sort is required by the spec.

Assembled:

```sql
WITH daily AS (                                                            -- step 1
  SELECT visited_on, SUM(amount) AS day_total
  FROM Customer
  GROUP BY visited_on
),
windowed AS (                                                              -- step 2
  SELECT visited_on,
         SUM(day_total) OVER (ORDER BY visited_on ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS amount,
         ROW_NUMBER()   OVER (ORDER BY visited_on)                                          AS day_no
  FROM daily
)
SELECT visited_on, amount, ROUND(amount / 7, 2) AS average_amount         -- step 4
FROM windowed
WHERE day_no >= 7                                                          -- step 3
ORDER BY visited_on;
```

Self-check before you submit: run it on exactly 6 days (empty result) and exactly 7 days (one row). Then check one day by hand: add the seven daily totals yourself.

## 5. Approaches: brute force → optimal

### Approach 1: self-join on a date range (`solutions/01_self_join_range.sql`)

```sql
WITH daily AS (SELECT visited_on, SUM(amount) AS day_total FROM Customer GROUP BY visited_on)
SELECT d1.visited_on, SUM(d2.day_total) AS amount, ROUND(SUM(d2.day_total) / 7, 2) AS average_amount
FROM daily d1
JOIN daily d2 ON d2.visited_on BETWEEN DATE_SUB(d1.visited_on, INTERVAL 6 DAY) AND d1.visited_on
GROUP BY d1.visited_on
HAVING COUNT(*) = 7
ORDER BY d1.visited_on;
```

**Why it is correct:** every day is joined to the days in the calendar interval ending at it. A day has "six earlier days available" exactly when that interval contains 7 days, which `HAVING COUNT(*) = 7` checks. This is the pre-window-function way to write a moving sum.

**Cost model (reasoned):** with *D* days, the range join compares days with days: about *D²* comparisons unless an index narrows each lookup to 7 rows, and the daily CTE is a derived table with no useful index of its own. It is therefore quadratic in the number of days, and the first to hit the 60-second cap in the bench.

### Approach 2: calendar `RANGE` window straight on the customer rows (`solutions/02_range_window_on_raw_rows.sql`)

```sql
SELECT DISTINCT visited_on, amount, ROUND(amount / 7, 2) AS average_amount
FROM (SELECT visited_on,
             SUM(amount) OVER (ORDER BY visited_on RANGE BETWEEN INTERVAL 6 DAY PRECEDING AND CURRENT ROW) AS amount
      FROM Customer) t
WHERE visited_on >= (SELECT MIN(visited_on) + INTERVAL 6 DAY FROM Customer)
ORDER BY visited_on;
```

**Why it is correct:** `RANGE` with an interval frames by date value, not by row count, and all rows of one day are peers, so every customer row of a day carries the same 7-day total. `DISTINCT` collapses them to one row per day. The date comparison removes the first six days.

**Cost model (reasoned):** no pre-aggregation, so the window sorts and evaluates every customer row instead of every day. If a day has 50 customers, it does 50× the window work and then throws 49/50 of it away in `DISTINCT`. Linear, but with the larger constant.

### Approach 3 (optimal): daily totals, then a `ROWS` window (`solutions/03_daily_then_rows_window.sql`)

The SQL is the assembled query in section 4.

**Why it is correct:** after the daily `GROUP BY` there is one row per day and (spec) no missing days, so the previous six rows are the previous six days. The window sums seven daily totals, `day_no >= 7` keeps only complete windows, and the divisor is the window size.

**Cost model (reasoned):** one scan to total each day, then a window over *D* rows (days) instead of *n* rows (visits). The aggregation is ordered by date, so with the covering index in `indexes.sql` it can stream; the window keeps a running sum, adding the new day and subtracting the one that left. Everything after the first step is proportional to the number of days.

**Measured** (`gen.py` data, generated by the bench workflow; the table is filled in automatically, so never type numbers here):

<!-- BENCH:29-restaurant-growth -->
_Measured 2026-11-04 by the bench workflow: MySQL 8.0.46, AMD EPYC 7763 64-Core Processor, 2 vCPU. Median of 3 runs after 1 warm-up; each statement capped at 60 s. Sizes are main-table rows from `gen.py`. Raw numbers and EXPLAIN ANALYZE: `bench/results/29-restaurant-growth.json`._

**Without indexes**

| Solution | 1,000 rows | 100,000 rows | 1,000,000 rows | × slower than optimal @ 1,000,000 |
|---|---:|---:|---:|---:|
| `01_self_join_range` | 1.72 ms | 1.31 s | timeout >60s | > 72× |
| `02_range_window_on_raw_rows` | 3.06 ms | 253 ms | 7.05 s | 8.4× |
| `03_daily_then_rows_window` (optimal) | 1.41 ms | 81.4 ms | 836 ms | 1.0× |

**With `indexes.sql`**

| Solution | 1,000 rows | 100,000 rows | 1,000,000 rows | × slower than optimal @ 1,000,000 |
|---|---:|---:|---:|---:|
| `01_self_join_range` | 1.38 ms | 1.22 s | timeout >60s | > 124× |
| `02_range_window_on_raw_rows` | 2.87 ms | 235 ms | 6.89 s | 14.3× |
| `03_daily_then_rows_window` (optimal) | 1.13 ms | 47.4 ms | 482 ms | 1.0× |

> GitHub-hosted runners are shared, noisy VMs: compare the ratios between rows, not the absolute times.
<!-- /BENCH -->

### Why the optimal one wins

Aggregating first shrinks the input of the expensive step from the number of visits to the number of days, and it makes the window frame mean what the spec means. Approach 2 does the same job with the same answer but pays for every raw row. Approach 1 pays for every pair of days. The bench table shows the size of both penalties. The cost of approach 3 is that it silently depends on the no-gaps guarantee (Assumptions), while approach 2 at least frames by calendar date.

## 6. At scale

**(a) What breaks first.** *Reasoned, then checked by the bench table:* approach 1, because it is quadratic in the number of days. Approach 2 next: its sort and window run over every customer row. Approach 3 grows linearly with the number of visits only in the `GROUP BY`; the window itself sees one row per day.

**(b) One machine, ~1M–100M rows.**
- `indexes.sql` adds `Customer (visited_on, amount)`. It is covering and in date order, so the daily `GROUP BY` can stream with a group aggregate instead of a temporary table, and the raw-row window of approach 2 can read the index. The bench runs every solution with and without it.
- The daily totals are small (a few thousand to a few hundred thousand rows for decades of data). If this query runs often, store them: a `daily_revenue` table makes the moving window a query over tiny data.
- Use `ROWS` only when the guarantee of one row per day holds. If gaps are possible, use `RANGE ... INTERVAL 6 DAY PRECEDING` on the daily rows or join to a calendar first (see `30-calculate-a-rolling-average-of-total-revenue`).

**(c) Distributed engines, billions of rows. *Reasoned, not measured.***
- *Pre-aggregation is the whole game:* `SUM` is decomposable, so each task totals its own visits per day and the shuffle carries one row per (task, day). The window then sees *D* rows, whatever the number of visits. A window over raw rows would shuffle every visit.
- *The window itself:* `OVER (ORDER BY visited_on)` has no `PARTITION BY`, so it runs on a single partition. That is acceptable here only because the pre-aggregated input is tiny (days, not visits). Never run it over the raw visits.
- *Pruning:* a "last N days" variant becomes a range predicate on `visited_on`, so a table clustered by date reads only the recent micro-partitions or files. Keep the six extra days before the range start.
- *Exact vs approximate:* the totals must be exact. Nothing here uses `COUNT(DISTINCT)`.

**(d) The data-engineering answer.** Maintain the daily totals incrementally and slide the window over the small table. A day's total changes only when its visits change:

```sql
-- daily_revenue(visited_on PRIMARY KEY, day_total). Apply each batch of visits by day, then re-read only recent days.
-- Snowflake / ANSI MERGE (UNVERIFIED):
MERGE INTO daily_revenue t
USING (SELECT visited_on, SUM(amount) AS day_total FROM visit_batch GROUP BY visited_on) s
ON t.visited_on = s.visited_on
WHEN MATCHED THEN UPDATE SET day_total = t.day_total + s.day_total
WHEN NOT MATCHED THEN INSERT (visited_on, day_total) VALUES (s.visited_on, s.day_total);

-- MySQL equivalent (no MERGE):
INSERT INTO daily_revenue (visited_on, day_total)
SELECT visited_on, SUM(amount) FROM visit_batch GROUP BY visited_on
ON DUPLICATE KEY UPDATE day_total = day_total + VALUES(day_total);
```

The report is then the approach 3 query over `daily_revenue`. Caveats: re-running a batch double-counts unless batches are tracked (a watermark or a batch id per row). Late visits for an old day change that day's total and the seven windows that contain it, so recompute the windows for those dates only. If a day can be missing, add a calendar so the `ROWS` frame stays valid.

## 7. Edge cases

Each "breaks" claim below is checked by execution: `mistakes/*.sql` are tempting wrong queries, and the harness asserts that each one fails every dataset it names (`harness/test_mistakes.py`).

| Case | Dataset | Wrong queries it catches (`mistakes/`) |
|---|---|---|
| Several customers on the same day; windows that drop and gain days | `tests/edge_typical.sql` | `no_preaggregation`, `avg_of_raw_rows`, `no_seventh_day_filter`, `eight_day_window`, `own_day_amount`, `no_rounding` |
| Exactly 7 days of data: a single output row | `tests/edge_exactly_seven_days.sql` | `no_seventh_day_filter` (returns 7 rows), `no_preaggregation`, `own_day_amount` |
| Only 6 days of data: empty result | `tests/edge_fewer_than_seven_days.sql` | `no_seventh_day_filter` |
| Totals not divisible by 7 (every remainder), month end and a leap day | `tests/edge_rounding_month_boundary.sql` | `no_rounding`, `eight_day_window`, `own_day_amount` |
| Output order (rows inserted out of date order) | `tests/edge_ordering.sql` | `order_descending` |

The generator `gen.py` produces consecutive days with skewed totals that are rarely divisible by 7; at larger sizes it also crosses month, year and leap-day boundaries. The differential test checks all three approaches on it.

No approach in `solutions/` is broken by any of these.

## 8. Interviewer follow-ups

1. **"Some days have no customers."** Then `ROWS` is wrong: it counts rows, not days. Build a calendar, LEFT JOIN the daily totals, replace NULL with 0 (`COALESCE`), and decide whether a window that starts before the first data day should be reported. That is `30-calculate-a-rolling-average-of-total-revenue`.
2. **"Why divide by 7 and not take `AVG`?"** `AVG` over the window of daily rows gives the same number for a full window, but `AVG` over the raw customer rows does not (`mistakes/avg_of_raw_rows.sql`). Dividing by the window length also stays right if a missing day is treated as 0.
3. **"Rolling window of N days as a parameter."** Replace both 6 and 7 by `N − 1` and `N`, and `day_no >= N`. Say that the first `N − 1` days are left out by design.
4. **"Report the first six days too, with partial windows."** Remove the `day_no` filter and decide on the divisor: the number of days in the window (`COUNT(*) OVER (...)`), or 7 as if the missing days were zero.
5. **"RANGE vs ROWS?"** `ROWS` counts physical rows, `RANGE` groups by value. With one row per day they agree. With duplicates or gaps they don't, and `RANGE ... INTERVAL` gives calendar semantics.

## 9. Snowflake notes (UNVERIFIED)

`snowflake.sql` keeps the shape of approach 3. What changes, and why:

- **`QUALIFY ROW_NUMBER() OVER (...) >= 7`** removes the `day_no` column and the outer filter layer.
- `ROUND(amount / 7, 2)` works unchanged: dividing integers yields a decimal in both engines, and `ROUND` fixes the number of decimals.
- No secondary indexes: `indexes.sql` has no equivalent. The daily `GROUP BY` is a hash aggregation, and clustering `Customer` by `visited_on` helps range-restricted variants (pruning), not the full-history query.
- Snowflake supports `RANGE BETWEEN INTERVAL '6 days' PRECEDING AND CURRENT ROW` as well, so approach 2 can be ported, but the same cost argument applies: aggregate first.
- Unquoted identifiers are upper-cased in the result: `VISITED_ON`, `AMOUNT`, `AVERAGE_AMOUNT`.

## 10. Pattern links

Same pattern (running totals / moving windows):
- `28-last-person-to-fit-in-the-bus`: an unbounded running total with a threshold instead of a fixed-size window.
- `30-calculate-a-rolling-average-of-total-revenue`: the same moving window over a generated calendar, so missing days count as 0.

Related:
- `04-monthly-transactions-i`: the `GROUP BY` bucket step before any further processing.
- `09-count-salary-categories`: building a scaffold when the zero rows don't exist in any table, which is what a gap in the dates would require here.
