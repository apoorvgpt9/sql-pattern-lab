# 17 · Seasonal Sales Analysis

## 1. Problem & trigger phrases

Original: [Seasonal Sales Analysis](https://leetcode.com/problems/seasonal-sales-analysis/) (LeetCode 3564, medium). Read the statement there; this guide only restates the spec in its own words.

**Spec (own words):** every sale belongs to a season decided by its month alone (Dec–Feb Winter, Mar–May Spring, Jun–Aug Summer, Sep–Nov Fall; the year is ignored). For each season, add up quantity and revenue (quantity × unit price) per product category. Return the single best category per season: most units, then highest revenue, then alphabetically first category. Output `season`, `category`, `total_quantity`, `total_revenue`, ordered by season as a string.

| Trigger phrase | What it forces in SQL |
|---|---|
| "most popular product category for each season" | Two grains stacked. First aggregate sales to **(season, category)**; then pick the best row **per season**. A single `GROUP BY season, category` is only half the answer; picking the best needs a second step (rank, or "nobody beats me"). |
| "If there is still a tie" | The ranking key has three levels: `total_quantity DESC, total_revenue DESC, category ASC`. The last key is what makes the order total, so exactly one row survives per season. With `RANK()` and only two keys, a full tie returns two rows. |
| "Winter: December, January, February" | A `CASE` on `MONTH(sale_date)`. Winter wraps around the year end, so `BETWEEN 12 AND 2` is an empty range: use `IN (12, 1, 2)`. The year is not part of the key: December 2023 and January 2024 are the same Winter, so grouping by `YEAR()` too is wrong. |

## 2. Schema & grain

| Table | One row means | Keys that matter here |
|---|---|---|
| `sales` | one sale (a product, a date, units, a unit price) | `sale_date` (→ season), `quantity`, `price`, `product_id` |
| `products` | one product | `product_id` (PK), `category` (the grouping attribute) |

**Output grain:** one row per season that has sales (at most 4), carrying the winning category and its totals. Output order is `season` ascending as a string, which is Fall, Spring, Summer, Winter: neither calendar order nor business order.

**Where the grain changes:** there are two collapses.
1. Sale grain → **(season, category)** grain: the `GROUP BY`. Revenue must be computed **per sale** (`quantity * price`) before summing. `SUM(quantity) * SUM(price)` is a different number.
2. (season, category) → **season** grain: keep the winner. This is a ranking step on already-aggregated rows, not on sales.

`category` lives on `products`, so the join to `products` happens somewhere before collapse 1 ends. *Where* it happens is what separates the approaches: before the aggregation (one join row per sale) or after a first aggregation to (product, season) (one join row per product and season).

## Assumptions

- **Sales of unknown products are ignored.** `sales.product_id` has no foreign key, so a sale can reference a product that is not in `products`. Its category is unknown, so it cannot be part of any (season, category) group. The solutions use an inner join, and a season whose only sales are of unknown products does not appear. The spec is silent on this; it is tested by `tests/edge_orphan_sales.sql`.
- **Nothing is NULL.** The spec says nulls are not a concern, so `schema.sql` declares every column the query reads `NOT NULL`.
- **Revenue is an exact decimal.** `price` is `DECIMAL(10,2)`, so `SUM(quantity * price)` carries 2 decimals with no rounding; no `ROUND` is needed.

## 3. Hint ladder

<details><summary>Hint 1</summary>

Pattern: **aggregate, then top-1 per group**, with a multi-key tie-break. "Best X for each Y" always means: compute the per-(Y, X) numbers, then rank the X within each Y.

</details>

<details><summary>Hint 2</summary>

Shape: (1) turn each sale's date into a season label. (2) Sum quantity and revenue per (season, category), which needs `products` for the category. (3) Within each season keep the one row that wins on quantity, then revenue, then category name. (4) Sort the result by season.

</details>

<details><summary>Hint 3</summary>

Key trick: put all three tie-break keys in the ranking window and use `ROW_NUMBER()`: `ORDER BY total_quantity DESC, total_revenue DESC, category ASC`. Because `category` is unique within a season, there is never a tie left, so `ROW_NUMBER` is safe and returns exactly one row. Compute revenue as `SUM(quantity * price)`, and write Winter as `MONTH(sale_date) IN (12, 1, 2)`.

</details>

## 4. Decomposition

Read "most popular category for each season" backwards: *each season* is the partition, *most popular category* is the ordering inside it, and the numbers being compared (units, revenue) do not exist yet and have to be computed first.

1. **`prod_season`: label each sale with a season and sum per (product, season).**
   *Why a CASE and a GROUP BY here:* the season is derived from the date, so it must exist as a column before anything can be grouped by it. Aggregating per product *before* the join shrinks the big table to at most 4 rows per product. `SUM(quantity * price)` is decomposable (a sum of partial sums is the same sum), so aggregating twice is safe.
2. **`cat_season`: join `products`, then `GROUP BY season, category`.**
   *Why a JOIN here:* the category is an attribute of the product. An inner join is deliberate: a sale of an unknown product has no category and no group to join (see Assumptions). *Why a second GROUP BY:* several products share a category, and "popular category" means their combined totals.
3. **`ranked`: `ROW_NUMBER()` per season over `total_quantity DESC, total_revenue DESC, category ASC`.**
   *Why a window here:* we must keep one row per season out of the (season, category) rows without losing the other columns. `GROUP BY season` with `MAX` would give the winning number but not the winning category's name; a window keeps the whole row.
4. **Final: `WHERE rn = 1 ORDER BY season`.**
   *Why a filter and a sort:* the window cannot be filtered in the `SELECT` where it is computed, hence the CTE. The spec fixes the output order, so `ORDER BY season` is part of the answer.

```sql
WITH prod_season AS (                                  -- step 1: sale grain -> (product, season)
  SELECT product_id,
         CASE WHEN MONTH(sale_date) IN (12, 1, 2) THEN 'Winter'
              WHEN MONTH(sale_date) IN (3, 4, 5)  THEN 'Spring'
              WHEN MONTH(sale_date) IN (6, 7, 8)  THEN 'Summer'
              ELSE 'Fall' END AS season,
         SUM(quantity) AS qty, SUM(quantity * price) AS revenue
  FROM sales
  GROUP BY product_id, season
), cat_season AS (                                     -- step 2: -> (season, category)
  SELECT ps.season, p.category,
         SUM(ps.qty) AS total_quantity, SUM(ps.revenue) AS total_revenue
  FROM prod_season ps
  JOIN products p ON p.product_id = ps.product_id
  GROUP BY ps.season, p.category
), ranked AS (                                         -- step 3: three-level winner per season
  SELECT cs.*,
         ROW_NUMBER() OVER (PARTITION BY season
                            ORDER BY total_quantity DESC, total_revenue DESC, category ASC) AS rn
  FROM cat_season cs
)
SELECT season, category, total_quantity, total_revenue
FROM ranked
WHERE rn = 1                                           -- step 4
ORDER BY season;
```

Step 1 is an optimisation, not part of the logic: dropping it and grouping the joined rows by (season, category) directly gives the same result (that is approach 3, the one labelled optimal). Whether the pre-aggregation pays off depends on how expensive the join is in your engine. On MySQL the bench says it pays at 100K rows (about 1.8× faster) and costs at 1M rows (about 2× slower), because its (product, season) group-by grows with the catalogue (section 5). Learn the decomposition with step 1, and ship it without step 1 unless the join is the expensive part.

Self-check before you submit: at most 4 rows, one per season, no season repeated. Then take one boundary day (31 May, 1 June, 29 February) and confirm it lands in the season you expect.

## 5. Approaches: brute force → optimal

### Approach 1: "nobody beats me" with NOT EXISTS (`solutions/01_not_exists_anti_join.sql`)

```sql
WITH cat_season AS (  -- join sales to products, GROUP BY season, category; SUM(quantity), SUM(quantity * price)
  ...
)
SELECT a.season, a.category, a.total_quantity, a.total_revenue
FROM cat_season a
WHERE NOT EXISTS (
  SELECT 1 FROM cat_season b
  WHERE b.season = a.season
    AND ( b.total_quantity > a.total_quantity
       OR (b.total_quantity = a.total_quantity AND b.total_revenue > a.total_revenue)
       OR (b.total_quantity = a.total_quantity AND b.total_revenue = a.total_revenue
           AND b.category < a.category) ) )
ORDER BY a.season;
```

**Why it is correct:** a category survives only if no category in its season is strictly better under the three-level order. Since the order is total (category is unique within a season), exactly one category survives per season. This is the natural first attempt for people who think "max per group" before "window function", and it spells out the tie-break rule explicitly in the SQL.

**Cost model (reasoned):** the anti-join runs on the aggregated `cat_season` rows, not on sales: at most 4 × (number of categories) rows, so its cost is negligible. The expensive part is the aggregation underneath it: `sales` is joined to `products` first (one joined row per sale) and then grouped. MySQL materialises the CTE once and probes it. Do not read the NOT EXISTS as the bottleneck here; the bench numbers are the arbiter.

### Approach 2: pre-aggregate, then join, then rank (`solutions/02_preaggregate_then_rank.sql`)

The SQL is the assembled query in section 4.

**Why it is correct:** the first CTE sums per (product, season); the second re-sums those partial sums per (season, category). Re-summing is exact because `SUM` and `SUM(quantity * price)` are additive. The ranking step is the same as approach 3.

**Cost model (reasoned):** one pass over `sales` into a group-by keyed on (product_id, season): at most 4 rows per product come out. The join to `products` then happens on that much smaller input (products × up to 4 rows, not the number of sales), and the second group-by works on that small set too. The shape is "reduce first, then join", the same idea as problem 01 approach 3. A hash group-by on (product_id, season) still has to touch every sales row once, and its temporary table has up to 4 × products groups, far more than the (season, category) groups of the other approaches; the second aggregation then has to run over all of them.

### Approach 3 (optimal): join, group, rank (`solutions/03_join_group_rank.sql`)

The same `cat_season` CTE, then `ROW_NUMBER() OVER (PARTITION BY season ORDER BY total_quantity DESC, total_revenue DESC, category ASC)` and `WHERE rn = 1`.

**Why it is correct:** the window ordering is the three-level rule, and `ROW_NUMBER` over a total order picks exactly one row. Replacing the anti-join with a window removes the three-way `OR` and makes the rule readable as one `ORDER BY`.

**Cost model (reasoned):** identical aggregation cost to approach 1, because it has the same join-then-group shape: one joined row per sale feeds a group-by on an expression (`CASE` over the month) plus `category`. That group-by cannot be served by an index, so MySQL builds a temporary table keyed on (season, category), but with only 4 × (number of categories) groups the table is tiny and stays in memory. The join to `products` is a primary-key lookup per sale. The ranking runs on at most a few dozen rows and costs nothing measurable by comparison.

**Measured** (`gen.py` data, generated by the bench workflow; the table is filled in automatically, so never type numbers here):

<!-- BENCH:17-seasonal-sales-analysis -->
_Measured 2026-11-04 by the bench workflow: MySQL 8.0.46, AMD EPYC 7763 64-Core Processor, 2 vCPU. Median of 3 runs after 1 warm-up; each statement capped at 60 s. Sizes are main-table rows from `gen.py`. Raw numbers and EXPLAIN ANALYZE: `bench/results/17-seasonal-sales-analysis.json`._

**Without indexes**

| Solution | 1,000 rows | 100,000 rows | 1,000,000 rows | × slower than optimal @ 1,000,000 |
|---|---:|---:|---:|---:|
| `01_not_exists_anti_join` | 2.84 ms | 186 ms | 1.93 s | 1.0× |
| `02_preaggregate_then_rank` | 1.86 ms | 106 ms | 4.08 s | 2.1× |
| `03_join_group_rank` (optimal) | 2.63 ms | 187 ms | 1.98 s | 1.0× |

> GitHub-hosted runners are shared, noisy VMs: compare the ratios between rows, not the absolute times.
<!-- /BENCH -->

### Why the optimal one wins

It wins on stability, not by a wide margin, and the bench shows a crossover worth knowing. Approaches 1 and 3 run the same aggregation (a primary-key lookup per sale, then a group-by with a few dozen groups) and are within noise of each other at every size. The NOT EXISTS is not the slow part; the ranking step costs nothing measurable. Approach 2 is the interesting one. At 100K rows it is the **fastest**, about 1.8× faster than approach 3, because it skips the 100K primary-key lookups and joins only about 4K pre-aggregated rows. At 1M rows it is the **slowest**, about 2× slower. Its first group-by, keyed on (product_id, season), grows with the catalogue (about 40K groups at 1M rows against 4K at 100K). In the plan, that one aggregation goes from about 0.08 s to 3.8 s, roughly 4× more time per input row; the plan does not show why. So "reduce before you join" is a conclusion about engines where the join is expensive (a shuffle), not a rule for a primary-key lookup join, and a two-size benchmark can rank the same query first and last.

## 6. At scale

**(a) What breaks first.** *Measured to 1M rows, reasoned beyond:* the group-by on a derived expression over the full `sales` table, in every approach: nothing can index a `CASE` over the month. The approach whose group-by has the most groups (approach 2, keyed on product and season) degrades first. Measured, its first aggregation grows from about 0.08 s at 100K rows to 3.8 s at 1M, far faster than the input, while the (season, category) group-bys of approaches 1 and 3 stay tiny and scale linearly (about 0.19 s → 1.9 s). The join to `products` is a key lookup, so it scales linearly with the number of sales.

**(b) One machine, ~1M–100M rows.**
- There is no index worth recommending, so there is no `indexes.sql`. The query reads every sale (a season covers a quarter of every year), so an index cannot skip rows, and the table is narrow enough that a covering index is about as wide as the base table. The group key contains an expression of the date, which an index cannot provide in order.
- A real lever is to precompute what does not change. Closed periods never change, so repeated runs should read a rollup (section 6d) instead of the raw sales.
- If the question is restricted to a date range ("only the last two years"), a range predicate on `sale_date` plus an index on `sale_date` does help, because it reduces the rows read. Write it as a half-open range on the raw column, never `YEAR(sale_date) >= ...`.

**(c) Distributed engines, billions of rows. *Reasoned, not measured.***
- *Shuffle:* in Spark-style engines, `GROUP BY product_id, season` runs a map-side partial aggregation, so only partial sums cross the network, one row per (task, product, season). The join with `products` (a dimension table, small) is then a broadcast join: no shuffle of the big side at all. Joining first would force the join keys of every sale through the network unless `products` is broadcast (then it is cheap too, but the group-by after it still has to shuffle one row per sale per key unless partial aggregation applies).
- *Skew:* a few products or categories with most of the sales would overload one reducer if the shuffle key is a skewed value. Pre-aggregating to (product, season) caps the contribution of any hot product to 4 rows.
- *Snowflake:* pruning does not help (all dates are needed) unless the question is restricted to a period. `QUALIFY ROW_NUMBER() ... = 1` removes the ranking CTE. The final ranking operates on at most a few dozen rows; it is irrelevant to the cost.
- *Things to avoid:* a global sort (only `ORDER BY season` on four rows is needed); `COUNT(DISTINCT)` style tricks are not needed because everything here is additive. Approximate aggregation is not acceptable for "the winner", because a tie decided by a 0.1% error is simply a wrong answer.

**(d) The data-engineering answer.** The fact table is append-only and seasons only depend on the month. Maintain a rollup at **(month-start, category)** grain, with quantity and revenue, fed incrementally by each batch of sales; the season query reads at most 12 rows per category per year instead of billions of sales:

```sql
-- sales_month_category(month_start DATE, category VARCHAR, qty BIGINT, revenue DECIMAL(18,2),
--                      PRIMARY KEY (month_start, category))
-- Snowflake / ANSI MERGE (UNVERIFIED):
MERGE INTO sales_month_category t
USING (SELECT DATE_TRUNC('month', s.sale_date) AS month_start, p.category,
              SUM(s.quantity) AS qty, SUM(s.quantity * s.price) AS revenue
       FROM sales_batch s                        -- only rows not yet applied (by sale_id watermark)
       JOIN products p ON p.product_id = s.product_id
       GROUP BY 1, 2) b
ON t.month_start = b.month_start AND t.category = b.category
WHEN MATCHED THEN UPDATE SET qty = t.qty + b.qty, revenue = t.revenue + b.revenue
WHEN NOT MATCHED THEN INSERT (month_start, category, qty, revenue)
                      VALUES (b.month_start, b.category, b.qty, b.revenue);

-- MySQL equivalent:
INSERT INTO sales_month_category (month_start, category, qty, revenue)
SELECT DATE_FORMAT(s.sale_date, '%Y-%m-01'), p.category, SUM(s.quantity), SUM(s.quantity * s.price)
FROM sales_batch s JOIN products p ON p.product_id = s.product_id
GROUP BY 1, 2
ON DUPLICATE KEY UPDATE qty = qty + VALUES(qty), revenue = revenue + VALUES(revenue);
```

The season question then runs steps 2–4 of the decomposition over this table, replacing `MONTH(sale_date)` with `MONTH(month_start)`. Caveats that interviewers probe: the join with `products` bakes the **category at load time** into the rollup, so if a product changes category, history is not restated unless you rebuild the affected months (a slowly-changing-dimension decision); applying a batch twice double-counts, so track a watermark and make loads idempotent; returns or corrected sales need a negative row or a rebuild of the affected months.

## 7. Edge cases

Each "breaks" claim below is checked by execution: `mistakes/*.sql` are the tempting wrong queries, and the harness asserts that each one fails every dataset it names (`harness/test_mistakes.py`).

| Case | Dataset | Wrong queries it catches (`mistakes/`) |
|---|---|---|
| Category total across two products beats any single product | `tests/edge_typical.sql` | `rank_products_not_categories` |
| Winter months written as `BETWEEN 12 AND 2` (empty range) | `tests/edge_typical.sql`, `tests/edge_season_boundaries.sql` | `between_wraparound` |
| Revenue as `SUM(quantity) * SUM(price)` (several sales at different prices) | `tests/edge_typical.sql`, `tests/edge_tiebreak.sql`, `tests/edge_season_boundaries.sql` | `sum_qty_times_sum_price` |
| Tie on quantity, revenue decides (and the revenue winner sorts later alphabetically) | `tests/edge_tiebreak.sql` (Summer) | `skip_revenue_key` (jumps from quantity to the alphabetical key) |
| Higher revenue but fewer units: quantity is the primary key | `tests/edge_tiebreak.sql` (Fall) | `revenue_before_quantity` |
| Tie on quantity **and** revenue across three categories (one of them split over two sales) | `tests/edge_tiebreak.sql` (Spring, Winter) | `rank_without_category_tiebreak` (two rows for one season) |
| First/last day of every season; 29 February; Winter spanning Dec–Feb across two calendar years | `tests/edge_season_boundaries.sql` | `group_by_year_too` (Winter split in two rows), `between_wraparound` |
| Sales of a product that is not in `products` (a season with only such sales is absent) | `tests/edge_orphan_sales.sql` | `left_join_products` (a NULL category wins the season) |
| `sales` empty | `tests/edge_no_sales.sql` | none; `GROUP BY` over no rows returns no rows |
| Output order: season string-ascending while quantity rises the other way | `tests/edge_ordering.sql` | `order_by_quantity_desc` |

No approach in `solutions/` is broken by any of these.

## 8. Interviewer follow-ups

1. **"Top two categories per season."** Change `rn = 1` to `rn <= 2`. With ties at the boundary the question becomes whether to keep tied rows (`RANK`/`DENSE_RANK`) or cut at exactly two (`ROW_NUMBER` with the full tie-break): the same trade-off as `19-department-top-three-salaries`.
2. **"Why not group by month and ignore seasons?"** The business rule is that seasons are *unions of months across years*. Month-level aggregation is the right intermediate storage (section 6d), and seasons are derived from it.
3. **"What if the southern hemisphere uses flipped seasons?"** The mapping becomes a lookup table `(region, month) → season`, joined in step 1. A hard-coded `CASE` is fine for one rule and wrong for two, because a lookup table can be audited and changed without editing SQL.
4. **"Return the runner-up's gap too."** Add `LEAD(total_quantity)` or a second `ROW_NUMBER` and self-join on `rn = 1 / rn = 2`. This is the point where the window version stays readable and approach 1's NOT EXISTS does not.
5. **"Why `ROW_NUMBER` here but `RANK` in problem 16?"** Problem 16 *wants* tied rows. This one wants exactly one row, and the third key (category) removes every tie, so `ROW_NUMBER` is deterministic. If the third key were missing, the correct response would be to ask what should happen on a tie, not to rely on `ROW_NUMBER`'s arbitrary choice.

## 9. Snowflake notes (UNVERIFIED)

`snowflake.sql` keeps the shape of approach 2 (pre-aggregate by product and season, then join), which is the form that avoids shuffling every sale in a distributed engine (reasoned, UNVERIFIED). What changes, and why:

- `QUALIFY ROW_NUMBER() OVER (...) = 1` applies the filter directly after the aggregation and removes the ranking CTE. The `ORDER BY` of the window uses the aggregates directly (window functions are evaluated after `GROUP BY`), which is shorter but easier to misread than the CTE form.
- There are no secondary indexes; a clustering key on `sale_date` only matters if the question is restricted to a period.
- `SUM(quantity * price)` on `NUMBER(10,2)` keeps scale 2. If `price` were `FLOAT`, totals could differ in the last digits between plans, and equality-based tie-breaks would silently stop working. That is a reason to store money as `NUMBER`.
- Unquoted identifiers are upper-cased (`SEASON`, `CATEGORY`); the column names come back in upper case.

## 10. Pattern links

Same pattern (aggregate to a coarser grain, then rank within a group, with tie-breaks):
- `16-department-highest-salary`: the same top-1-per-group step without the aggregation, keeping ties on purpose.
- `19-department-top-three-salaries`: top-N per group with `DENSE_RANK`.
- `18-find-stores-with-inventory-imbalance`: rank the same group in two directions in one query.
- `04-monthly-transactions-i`: the date-bucketing half of this problem (month → bucket, then conditional aggregation).
- `30-calculate-a-rolling-average-of-total-revenue`: pre-aggregate to a calendar grain, then compute over it.
