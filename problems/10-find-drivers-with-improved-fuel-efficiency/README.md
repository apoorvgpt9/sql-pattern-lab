# 10 · Find Drivers with Improved Fuel Efficiency

## 1. Problem & trigger phrases

Original: [Find Drivers with Improved Fuel Efficiency](https://leetcode.com/problems/find-drivers-with-improved-fuel-efficiency/) (LeetCode 3601, medium). Read the statement there; this guide only restates the spec in its own words.

**Spec (own words):** each trip has an efficiency, distance divided by fuel. For each driver, take the mean efficiency of their January-June trips and of their July-December trips (any year; only the month matters). Report drivers who have trips in both halves and whose second-half mean is higher than the first-half mean. Show both means and their difference, each rounded to 2 decimals, best improvement first, ties by name.

| Trigger phrase | What it forces in SQL |
|---|---|
| "first half ... second half of the year" | Two buckets decided by `MONTH(trip_date)`: `BETWEEN 1 AND 6` and `BETWEEN 7 AND 12`. Both numbers must end up on **one row per driver**, which is a pivot: `AVG(CASE WHEN half = 1 THEN eff END)` next to `AVG(CASE WHEN half = 2 THEN eff END)`. |
| "trips in both halves" | Each driver needs a mean on both sides. A half with no trip yields a NULL mean, and `s > f` is unknown for NULL, so one comparison enforces "both exist" and "improved" together. Do not `COALESCE` the means to 0: that turns "no data" into "efficiency 0". |
| "efficiency improved" | Strictly `second > first`. A driver with equal means has not improved. |
| "distance_km / fuel_consumed for each trip" | The ratio is computed **per trip, before** averaging: the mean of ratios, not total distance over total fuel. The two differ whenever trips differ in length. |

Also hidden in the wording: "rounded to 2 decimals" applies to **three outputs**, but the improvement is taken from the unrounded means and rounded once. Rounding the two means and then subtracting gives a different, wrong number in some rows (section 4, step 5).

## 2. Schema & grain

| Table | One row means | Columns that matter |
|---|---|---|
| `drivers` | one driver | `driver_id`, `driver_name` (output and tie-break) |
| `trips` | one trip | `driver_id`, `trip_date` (month only), `distance_km`, `fuel_consumed` |

**Output grain:** one row per driver who improved. A driver appears at most once.

**Where the grain changes:** three steps, and the order matters.

1. *Row level, no grain change:* the trip's efficiency is an expression over one row. It must exist **before** the aggregation, because the spec averages ratios, not sums.
2. *Trip → (driver, half) → driver:* an average per bucket, with the two buckets side by side in one row (the pivot).
3. *Driver → name:* `drivers` is at driver grain, so it joins 1:1 onto the pivot result. Join after grouping and no name needs to travel through the `GROUP BY`.

`trips` has no foreign key: a trip can name a driver that is not in `drivers`. That driver has no row to report (the grain is `drivers`), so the join to `drivers` is also a filter.

## Assumptions

Confidence is `medium`: the statement says "improved" and leaves some corners open. Each choice below is recorded, and a dataset pins it down.

1. **Improved means strictly greater.** The source's own reference solution filters on `first < second`, and the title says "improved". A driver with equal means, or a decline, is excluded. Tested in `tests/edge_half_boundaries.sql` (Kai, 5 vs 5) and `tests/edge_none_improved.sql` (Max equal, Lia lower).
2. **The filter uses the unrounded means.** A driver whose second mean is 5.004 and first mean is 5.001 *did* improve, even though both display as 5.00 and the improvement displays as 0.00. Filtering on the rounded values would drop them. Tested in `tests/edge_rounding_trap.sql` (Ira). If you read the spec as "filter on what is displayed", this is the one place to change.
3. **Output order uses the displayed improvement.** `ORDER BY efficiency_improvement DESC` sorts on the rounded column, so two drivers who both display 1.00 are tied and the name decides. Tested in `tests/edge_ordering.sql` (Beth vs Cal).
4. **A trip with undefined efficiency is ignored**, not treated as 0 and not counted as "a trip in that half". Undefined means NULL distance, NULL fuel, or zero fuel. A driver whose only trips in a half are undefined therefore has no mean for that half and is excluded. Tested in `tests/edge_nulls_and_zero_fuel.sql`. The solutions write `NULLIF(fuel_consumed, 0)`; MySQL would return NULL for `x / 0` in a `SELECT` anyway, but Snowflake raises an error, so the guard keeps the query portable.
5. **A NULL `trip_date` is in neither half.** Same test dataset (Oro's NULL-date trip).
6. **Years are pooled.** January 2021 and January 2023 are both "first half". Tested in `tests/edge_half_boundaries.sql` (Jon).
7. **Drivers with no trips, or whose trips are only in `trips` but not in `drivers`, are not reported.** Tested in `tests/edge_typical.sql` (Eli; driver 99).

## 3. Hint ladder

<details><summary>Hint 1</summary>

Pattern: **pivot by conditional aggregation, then compare the two pivoted columns**. One row per driver, two buckets as two columns.

</details>

<details><summary>Hint 2</summary>

Shape: (1) turn each trip into a (driver, which half, efficiency) row, (2) group by driver and average efficiency separately for each half, (3) keep the drivers where the second average beats the first, (4) attach the name, (5) round and sort.

</details>

<details><summary>Hint 3</summary>

Key clauses: `AVG(CASE WHEN half = 1 THEN eff END)` (no `ELSE`, so the other half is NULL and `AVG` skips it), and `WHERE s > f` (NULL on either side drops the driver, which is the "both halves" rule). Compute the improvement as `ROUND(s - f, 2)` from the **unrounded** `s` and `f`. Guard the division with `NULLIF(fuel_consumed, 0)`.

</details>

## 4. Decomposition

Read the output columns left to right: id and name come from `drivers`, then three numbers that are all functions of two per-driver means. So the real work is "get two means onto one row per driver"; everything else is decoration.

1. **`trip_eff`: per trip, compute `half` and `eff = distance_km / NULLIF(fuel_consumed, 0)`.**
   *Why a row-level expression here:* "distance_km / fuel_consumed for each trip" says the ratio exists before any averaging. Putting it in a CTE keeps the ratio and the bucket in one place. `half` comes from `MONTH(trip_date)` alone, which is what "years are not separated" means.
2. **`halves`: `GROUP BY driver_id`, two `AVG(CASE …)` columns.**
   *Why a GROUP BY with conditional aggregation:* the output wants one row per driver with the halves side by side. A `WHERE half = 1` would remove the data for the other column, so each average carries its own `CASE` and `AVG` ignores the NULLs the `CASE` produces for the other half. This is grain change #2.
3. **Filter: `WHERE s > f`.**
   *Why a plain comparison covers two rules:* "trips in both halves" means both means exist; "improved" means the second is larger. If either mean is NULL the comparison is unknown and the row is dropped. No `IS NOT NULL` is needed, and no `COALESCE` is allowed.
4. **Join `drivers` on `driver_id`.**
   *Why a JOIN, and after the GROUP BY:* the name lives at driver grain. Joining after the aggregation is 1:1 and also removes trips of unknown drivers.
5. **`ROUND` and `ORDER BY`.**
   *Why round last, once:* `ROUND(s - f, 2)` uses the exact difference. Rounding the means first and then subtracting loses information. With first = 11.236 and second = 13.334 the exact difference is 2.098, which displays as 2.10; the rounded means 11.24 and 13.33 give 2.09. The sort key is the displayed `efficiency_improvement`, then `driver_name`.

Assembled (this is `solutions/03_conditional_aggregation.sql`):

```sql
WITH trip_eff AS (                                         -- step 1: row-level ratio + bucket
  SELECT driver_id,
         CASE WHEN MONTH(trip_date) BETWEEN 1 AND 6  THEN 1
              WHEN MONTH(trip_date) BETWEEN 7 AND 12 THEN 2 END AS half,
         distance_km / NULLIF(fuel_consumed, 0)                 AS eff
  FROM trips
),
halves AS (                                                -- step 2: trip grain -> driver grain, pivoted
  SELECT driver_id,
         AVG(CASE WHEN half = 1 THEN eff END) AS f,
         AVG(CASE WHEN half = 2 THEN eff END) AS s
  FROM trip_eff
  GROUP BY driver_id
)
SELECT d.driver_id, d.driver_name,                         -- step 4: names
       ROUND(h.f, 2)       AS first_half_avg,              -- step 5: round once, at the end
       ROUND(h.s, 2)       AS second_half_avg,
       ROUND(h.s - h.f, 2) AS efficiency_improvement
FROM halves h
JOIN drivers d ON d.driver_id = h.driver_id
WHERE h.s > h.f                                            -- step 3: both halves exist AND improved
ORDER BY efficiency_improvement DESC, d.driver_name ASC;
```

Self-check: pick one qualifying driver and recompute both means by hand from their trips. Then pick a driver with trips in only one half and confirm they are absent. Finally find two rows with the same displayed improvement and confirm they are in name order.

## 5. Approaches: brute force → optimal

### Approach 1: two scalar subqueries per driver (`solutions/01_correlated_subqueries.sql`)

```sql
SELECT x.driver_id, x.driver_name, ROUND(x.f, 2) AS first_half_avg, ROUND(x.s, 2) AS second_half_avg,
       ROUND(x.s - x.f, 2) AS efficiency_improvement
FROM (
  SELECT d.driver_id, d.driver_name,
         (SELECT AVG(t.distance_km / NULLIF(t.fuel_consumed, 0)) FROM trips t
           WHERE t.driver_id = d.driver_id AND MONTH(t.trip_date) BETWEEN 1 AND 6)  AS f,
         (SELECT AVG(t.distance_km / NULLIF(t.fuel_consumed, 0)) FROM trips t
           WHERE t.driver_id = d.driver_id AND MONTH(t.trip_date) BETWEEN 7 AND 12) AS s
  FROM drivers d
) x
WHERE x.s > x.f
ORDER BY efficiency_improvement DESC, x.driver_name ASC;
```

**Why it is correct:** the outer query is `drivers`, so each driver appears at most once, and a driver without trips gets two NULL means and is dropped by `s > f`. Each scalar subquery is the spec sentence for one half. It is the most natural first attempt because the spec is written per driver.

**Cost model (reasoned):** the two subqueries run once per driver, so without an index each run scans all of `trips`: about 2 × drivers × trips row visits, which grows quadratically when both grow together. With `indexes.sql` each run reads only that driver's index entries, and the total becomes roughly linear. `MONTH(trip_date)` wraps the column, so the month test is applied to each of the driver's entries rather than used as a range; that is fine because every trip of the driver is needed anyway.

### Approach 2: one aggregate per half, joined (`solutions/02_two_half_aggregates_joined.sql`)

```sql
WITH first_half  AS (SELECT driver_id, AVG(distance_km / NULLIF(fuel_consumed, 0)) AS avg_eff
                     FROM trips WHERE MONTH(trip_date) BETWEEN 1 AND 6  GROUP BY driver_id),
     second_half AS (SELECT driver_id, AVG(distance_km / NULLIF(fuel_consumed, 0)) AS avg_eff
                     FROM trips WHERE MONTH(trip_date) BETWEEN 7 AND 12 GROUP BY driver_id)
SELECT d.driver_id, d.driver_name, ROUND(f.avg_eff, 2) AS first_half_avg, ROUND(s.avg_eff, 2) AS second_half_avg,
       ROUND(s.avg_eff - f.avg_eff, 2) AS efficiency_improvement
FROM drivers d
JOIN first_half f  ON f.driver_id = d.driver_id
JOIN second_half s ON s.driver_id = d.driver_id
WHERE s.avg_eff > f.avg_eff
ORDER BY efficiency_improvement DESC, d.driver_name ASC;
```

**Why it is correct:** each CTE is at driver grain, so both joins are 1:1. The inner joins are right here because a driver must exist in both halves; a driver missing from either CTE correctly disappears. (This is the opposite of `08-odd-and-even-transactions`, where the same shape needed LEFT JOINs: there the spec wanted days kept, here it wants drivers dropped.)

**Cost model (reasoned):** two scans of `trips` (each filtered to one half) plus two small joins at driver grain. Linear in rows, no per-driver loop. The filter is on `MONTH(...)`, which no ordinary index can range-scan, so each scan reads about half the table.

### Approach 3 (optimal): one pass, conditional aggregation (`solutions/03_conditional_aggregation.sql`)

The SQL is the assembled query in section 4.

**Why it is correct:** one `GROUP BY driver_id` yields one row per driver that has any trip; the two `AVG(CASE …)` columns are the two half means, NULL where a half has no usable trip. The join to `drivers` is 1:1, and `s > f` drops every driver lacking a mean on either side. The NULL date lands in neither `CASE` branch.

**Cost model (reasoned):** one scan of `trips`, one aggregation keyed by `driver_id` with two accumulators per group (a sum and a count for each `AVG`), then a join of driver-grain rows to `drivers`. State is proportional to the number of drivers. With `indexes.sql` the scan comes in driver order and the aggregation can stream.

**Measured** (`gen.py` data, generated by the bench workflow; the table is filled in automatically, so never type numbers here):

<!-- BENCH:10-find-drivers-with-improved-fuel-efficiency -->
_Measured 2026-11-04 by the bench workflow: MySQL 8.0.46, Intel(R) Xeon(R) Platinum 8370C CPU @ 2.80GHz, 2 vCPU. Median of 3 runs after 1 warm-up; each statement capped at 60 s. Sizes are main-table rows from `gen.py`. Raw numbers and EXPLAIN ANALYZE: `bench/results/10-find-drivers-with-improved-fuel-efficiency.json`._

**Without indexes**

| Solution | 1,000 rows | 100,000 rows | 1,000,000 rows | × slower than optimal @ 1,000,000 |
|---|---:|---:|---:|---:|
| `01_correlated_subqueries` | 18.8 ms | timeout >60s | timeout >60s † | > 45× |
| `02_two_half_aggregates_joined` | 1.86 ms | 114 ms | 1.4 s | 1.0× |
| `03_conditional_aggregation` (optimal) | 1.74 ms | 107 ms | 1.33 s | 1.0× |

† not run at this size: it already timed out at a smaller size.

**With `indexes.sql`**

| Solution | 1,000 rows | 100,000 rows | 1,000,000 rows | × slower than optimal @ 1,000,000 |
|---|---:|---:|---:|---:|
| `01_correlated_subqueries` | 1.77 ms | 102 ms | 1.01 s | 1.3× |
| `02_two_half_aggregates_joined` | 1.59 ms | 85.3 ms | 862 ms | 1.1× |
| `03_conditional_aggregation` (optimal) | 1.4 ms | 75.9 ms | 764 ms | 1.0× |

> GitHub-hosted runners are shared, noisy VMs: compare the ratios between rows, not the absolute times.
<!-- /BENCH -->

### Why the optimal one wins

Approach 3 reads `trips` once and puts both means on the same row as they are computed, so the comparison `s > f` needs no join between the halves. Approach 2 reads it twice and has to re-join what was split; approach 1 repeats the work per driver. The single pass is also the form that carries over to distributed engines: `AVG` splits into a sum and a count that each task can compute locally (section 6c).

## 6. At scale

**(a) What breaks first.** *Reasoned, then checked by the bench table:* approach 1 without an index, since it is drivers × trips. Approach 2 next, because it scans `trips` twice and cannot use a date index for a `MONTH()` predicate. Approach 3 degrades most slowly, and its memory is bounded by the number of drivers.

**(b) One machine, ~1M–100M rows.**
- `indexes.sql` adds `trips (driver_id, trip_date, distance_km, fuel_consumed)`. It is *covering*: all three approaches read only those columns, so no row lookup into the clustered table is needed. It turns approach 1 into a short index range read per driver, and lets approach 3 aggregate in `driver_id` order without a temporary table.
- The first column is `driver_id`, not `trip_date`: nothing here filters by date range (the whole year pool is wanted), so a date-first index would not reduce the rows read.
- Do not "optimise" `MONTH(trip_date) BETWEEN 1 AND 6` into a date range: the halves are defined by month across all years, which is not a single contiguous range. A stored generated column `half` (or `trip_month`) would make the test cheaper to evaluate, but it does not remove any rows from the scan.
- The division is evaluated per row either way. If efficiency is queried often, store it as a generated column, but weigh the extra storage against recomputing a division.

**(c) Distributed engines, billions of rows. *Reasoned, not measured.***
- *Shuffle:* `AVG` decomposes into `(SUM, COUNT)`. Each task computes, per driver and per half, a partial sum of ratios and a count, and only these partials move in the shuffle by `driver_id`. Approach 2 shuffles twice (once per half) before the join. Approach 3 shuffles partial aggregates once.
- *Skew:* a fleet account or a placeholder driver with a large fraction of all trips would overload one reducer in a plan that shuffles raw rows. Partial aggregation shrinks it to one row per task, so the skew disappears.
- *Join:* the final join to `drivers` is between driver-grain rows and a small dimension, which is usually broadcast, so it costs no shuffle.
- *Pruning:* the wanted data is all trips (both halves, all years), so date pruning does not help here. It would help for a variant restricted to a year.
- *Things to avoid:* the per-driver loop of approach 1; a global sort of raw trips (the final sort is over qualifying drivers only, which is small). No `COUNT DISTINCT`, so no approximate-function question; a mean of ratios is exact and cheap to keep exact.

**(d) The data-engineering answer.** Averages cannot be merged, but sums and counts can. Keep per-driver, per-half **sums and counts**, fold each batch of new trips in, and compute the averages at read time:

```sql
-- driver_half_stats(driver_id, half, sum_eff DECIMAL(24,6), n_eff BIGINT, PRIMARY KEY (driver_id, half))
-- Snowflake / ANSI MERGE (UNVERIFIED):
MERGE INTO driver_half_stats t
USING (SELECT driver_id,
              IFF(MONTH(trip_date) <= 6, 1, 2)       AS half,
              SUM(distance_km / NULLIF(fuel_consumed, 0))                       AS sum_eff,
              COUNT(distance_km / NULLIF(fuel_consumed, 0))                     AS n_eff   -- counts non-NULL ratios only
       FROM trips_batch                         -- rows not yet applied (by trip_id watermark)
       WHERE trip_date IS NOT NULL
       GROUP BY driver_id, IFF(MONTH(trip_date) <= 6, 1, 2)) s
ON t.driver_id = s.driver_id AND t.half = s.half
WHEN MATCHED THEN UPDATE SET sum_eff = t.sum_eff + s.sum_eff, n_eff = t.n_eff + s.n_eff
WHEN NOT MATCHED THEN INSERT (driver_id, half, sum_eff, n_eff) VALUES (s.driver_id, s.half, s.sum_eff, s.n_eff);

-- Read side: one row per driver, same logic as approach 3 but over a tiny table.
SELECT d.driver_id, d.driver_name,
       ROUND(f.sum_eff / f.n_eff, 2) AS first_half_avg, ROUND(s.sum_eff / s.n_eff, 2) AS second_half_avg,
       ROUND(s.sum_eff / s.n_eff - f.sum_eff / f.n_eff, 2) AS efficiency_improvement
FROM drivers d
JOIN driver_half_stats f ON f.driver_id = d.driver_id AND f.half = 1 AND f.n_eff > 0
JOIN driver_half_stats s ON s.driver_id = d.driver_id AND s.half = 2 AND s.n_eff > 0
WHERE s.sum_eff / s.n_eff > f.sum_eff / f.n_eff
ORDER BY efficiency_improvement DESC, d.driver_name;
```

Caveats interviewers probe. *Idempotency*: reapplying a batch double-counts, so keep a watermark of applied `trip_id`s. *Corrections*: an edited or deleted trip needs its old contribution subtracted (negative sum and count) and its new one added, which needs before/after images from the source. *Why not store the average*: you cannot update a mean from a new batch without the count, and you cannot merge two means without both counts.

## 7. Edge cases

Each "breaks" claim below is checked by execution: `mistakes/*.sql` are the tempting wrong queries, and the harness asserts that each one fails every dataset it names (`harness/test_mistakes.py`).

| Case | Dataset | Wrong queries it catches (`mistakes/`) |
|---|---|---|
| Trips of different lengths in a half (mean of ratios ≠ ratio of sums) | `tests/edge_typical.sql` | `ratio_of_sums` |
| Driver with trips in one half only; driver without trips; trips of an unknown driver | `tests/edge_typical.sql`, `tests/edge_none_improved.sql` | `coalesce_missing_half_to_zero` (a one-sided driver compared against 0) |
| Improvement taken after rounding the means (11.24 vs 13.33 → 2.09, not 2.10) | `tests/edge_rounding_trap.sql` | `rounded_before_diff` |
| Real improvement smaller than a rounding step (displays 5.00 / 5.00 / 0.00) | `tests/edge_rounding_trap.sql` | `filter_on_rounded` |
| Repeating decimals (10/3, 20/3) under MySQL's 6-decimal division | `tests/edge_rounding_trap.sql` | `rounded_before_diff` |
| 30 Jun / 1 Jul, 1 Jan / 31 Dec | `tests/edge_half_boundaries.sql` | `june_in_second_half` |
| Same half in different years (years are pooled) | `tests/edge_half_boundaries.sql` | `group_by_year` |
| Exactly equal means; a decline | `tests/edge_half_boundaries.sql`, `tests/edge_none_improved.sql` | `gte_instead_of_gt` |
| NULL distance, NULL fuel, zero fuel | `tests/edge_nulls_and_zero_fuel.sql` | `undefined_trip_as_zero` (zero drags the mean down), `coalesce_missing_half_to_zero` |
| NULL `trip_date` | `tests/edge_nulls_and_zero_fuel.sql` | `else_second_half` (NULL falls into `ELSE`) |
| Ties on improvement, including a tie on the displayed value only | `tests/edge_ordering.sql` | `tie_break_by_driver_id`, `order_by_unrounded` |
| Both tables empty | `tests/edge_empty.sql` | none |

No approach in `solutions/` is broken by any of these.

## 8. Interviewer follow-ups

1. **"Why average the ratios and not divide total distance by total fuel?"** They answer different questions. The mean of per-trip ratios gives every trip equal weight; total distance over total fuel weights each trip by its fuel, which is the fleet-level economy figure (km per litre actually burned). The spec chose the first, and the two differ whenever trips differ in size. Say which you are computing and why.
2. **"Do it per year instead of pooling years."** Add `YEAR(trip_date)` to the group key: `GROUP BY driver_id, YEAR(trip_date)` and the output grain becomes (driver, year). Everything else carries over. That is exactly what `mistakes/group_by_year.sql` does by accident.
3. **"Improvement as a percentage."** `(s - f) / f * 100`. Decide what happens when `f` is 0 (guard with `NULLIF`), and round once at the end. Mind that MySQL's `/` returns extra decimals.
4. **"Use the median instead of the mean."** MySQL has no `MEDIAN`; you need a window function (`ROW_NUMBER`/`COUNT` per driver and half) and the middle one or two rows. Snowflake has `MEDIAN`. See `45-median-order-amount-per-store`.
5. **"Why `WHERE` on the CTE and not `HAVING`?"** Either works: `HAVING s > f` inside `halves` is equivalent. MySQL lets `HAVING` use select aliases; some engines do not. Filtering in the outer query is the portable and readable form.
6. **"What if `fuel_consumed` can be 0?"** The ratio is undefined: skip those trips (`NULLIF`) rather than error out or count them as efficiency 0. Say what that does to "trips in both halves" and that it is a business decision.

## 9. Snowflake notes (UNVERIFIED)

`snowflake.sql` keeps the shape of approach 3. What changes, and why:

- `IFF(cond, a, NULL)` replaces `CASE WHEN … THEN … END`. `AVG` ignores NULLs in both engines.
- **Division by zero raises an error in Snowflake** (MySQL's `SELECT` returns NULL). `NULLIF(fuel_consumed, 0)` is therefore required, not just defensive; `DIV0NULL(a, b)` is a shorthand.
- Numeric precision rules differ from MySQL's `div_precision_increment`: the number of decimals in `distance_km / fuel_consumed` is decided by Snowflake's own scale rule. The unrounded means can therefore carry different digits than the MySQL expected values, which only matters at a rounding boundary. Treat the spec's rounding example as a test to re-run on Snowflake rather than assume.
- `ROUND` on `NUMBER` rounds half away from zero, as in MySQL for `DECIMAL`. On `FLOAT` columns the result of rounding exact halves can differ.
- No indexes, so `indexes.sql` has no equivalent. A table clustered by `driver_id` gives better pruning for a driver-restricted query; for this full-table aggregate, bytes scanned dominate and only the four needed columns are read.
- `QUALIFY` is not needed here (no row-per-group selection). Unquoted identifiers return upper-cased.

## 10. Pattern links

Same pattern (pivot into buckets, then compare the buckets):
- `08-odd-and-even-transactions`: the basic conditional-aggregation pivot, by date instead of by driver.
- `11-analyze-subscription-conversion`: pivot per user by activity type, with a "both present" rule.
- `04-monthly-transactions-i`: several conditional aggregates in one `GROUP BY`.

Related (comparing an entity's earlier and later values):
- `22-find-students-who-improved`: first versus last, via window functions instead of a pivot.
- `26-find-consistently-improving-employees`: improvement across a sequence, not just two buckets.
