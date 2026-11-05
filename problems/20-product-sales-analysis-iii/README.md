# 20 · Product Sales Analysis III

## 1. Problem & trigger phrases

Original: [Product Sales Analysis III](https://leetcode.com/problems/product-sales-analysis-iii/) (LeetCode 1070, medium). Read the statement there; this guide only restates the spec in its own words.

**Spec (own words):** for every product, find the earliest year in which it has a sales row, and return every sales row of that product from that year: product id, that year (as `first_year`), quantity and unit price. A product with several rows in its first year contributes several output rows.

| Trigger phrase | What it forces in SQL |
|---|---|
| "first year each product was sold" | A per-product minimum: `MIN(year)` grouped or partitioned by `product_id`. "First" is defined by the **year column**, not by `sale_id`, and not by row order. The minimum is per product, not for the whole table. |
| "all sales entries for that product" | The output is **rows**, not one value per product. After finding the first year you must come back to row level and keep every row in that year. So: join back to the minimum, a correlated `= (SELECT MIN …)`, or a window `MIN() OVER`. `ROW_NUMBER() = 1`, `LIMIT 1` or a `GROUP BY` with sums drop or merge rows. |

## 2. Schema & grain

| Table | One row means | Keys that matter here |
|---|---|---|
| `Sales` | one sales entry for a product in a year | `product_id`, `year`, `quantity`, `price`. The primary key is `(sale_id, year)`: `sale_id` alone is **not** unique. |

**Output grain:** one row per `Sales` row that lies in its product's first year. Because `sale_id` is not in the output, two different sales entries with the same product, year, quantity and price produce two identical output rows. That is correct, and means `DISTINCT` is wrong.

**Where the grain changes:** the query first needs a **product-grain** fact (the earliest year) and then returns to **row grain**. The three approaches differ in how they get the product-grain fact back onto the rows:
- correlated subquery: recomputed per row;
- `GROUP BY` then join back: computed once per product, joined on `(product_id, year)`;
- window `MIN() OVER`: computed in the same pass and attached to every row, no join at all.

## 3. Hint ladder

<details><summary>Hint 1</summary>

Pattern: **first row (or rows) per key, keeping ties**. The "key" is the product; the thing that is first is the year; "keeping ties" means keeping every row at that year.

</details>

<details><summary>Hint 2</summary>

Shape: (1) find each product's earliest year. (2) Keep the rows whose year equals their own product's earliest year. (3) Select the requested columns, reporting the earliest year as `first_year`. Step 2 can be a join, a correlated subquery, or a window function that puts step 1's value on every row.

</details>

<details><summary>Hint 3</summary>

Key trick: compare for **equality** with the minimum, never take "the first row". With a window: `MIN(year) OVER (PARTITION BY product_id)` on each row, then `WHERE year = that`. If you join back, join on **both** `product_id` and `year`; year alone matches other products that sold in the same year.

</details>

## 4. Decomposition

"The first year each product was sold" is a fact about a *product*; "all sales entries … from that year" is a set of *rows*. Compute the fact, then use it to filter the rows.

1. **Per-row `first_year` = the minimum year of the row's product.**
   *Why a window aggregate here (or a GROUP BY + join):* we need a product-level number next to row-level data without losing the rows. `MIN(year) OVER (PARTITION BY product_id)` does exactly that: an aggregate with `PARTITION BY` but no `ORDER BY` is just "the group's minimum, repeated on each row".
2. **Filter `year = first_year`.**
   *Why a filter here:* "all entries from that year" is a row filter. Equality keeps every row in the year, including any number of ties; an inequality-based "no earlier row exists" would behave identically.
3. **Project `product_id, first_year, quantity, price`.**
   *Why no GROUP BY or DISTINCT:* the output grain equals the input grain for the surviving rows. Aggregating or de-duplicating changes the number of rows, which the spec does not allow.

```sql
SELECT product_id, first_year, quantity, price            -- step 3
FROM (
  SELECT product_id,
         year                                     AS yr,
         MIN(year) OVER (PARTITION BY product_id) AS first_year,   -- step 1
         quantity, price
  FROM Sales
) t
WHERE yr = first_year;                                    -- step 2
```

Self-check before you submit: take one product with a later-year row and confirm that row is gone; take one product with two first-year rows and confirm both are present; check that the output row count is at least the number of distinct products.

## 5. Approaches: brute force → optimal

### Approach 1: correlated `MIN` (`solutions/01_correlated_min.sql`)

```sql
SELECT s.product_id, s.year AS first_year, s.quantity, s.price
FROM Sales s
WHERE s.year = (SELECT MIN(s2.year) FROM Sales s2 WHERE s2.product_id = s.product_id);
```

**Why it is correct:** for each row, the subquery returns the earliest year of the row's product; the row passes if its year equals it. Every row in the first year passes, so ties and repeated rows are all kept, and no product can be left out (each product has a minimum year). It reads exactly like the requirement, which is why it is the natural first attempt.

**Cost model (reasoned):** one subquery per `Sales` row. With no index on `product_id`, each execution scans the whole table, which is quadratic. MySQL may rewrite the subquery, so confirm with `EXPLAIN`. Measured: without an index it times out at 100K rows. With `indexes.sql` (`product_id, year, …`) each `MIN(year)` could be one read at the start of a product's index range. The bench's EXPLAIN ANALYZE shows a covering lookup of the product's *whole* range (about 10 entries on average) instead, once per row. That is still linear in practice: about 6.9 s at 1M rows, 1.7× approach 3.

### Approach 2: window `MIN` (`solutions/02_window_min_year.sql`)

The SQL is the assembled query in section 4.

**Why it is correct:** the window computes each product's minimum year on every row of that product; filtering for equality is the same test as approach 1, but there is no second access to the table.

**Cost model (reasoned):** one scan. The window needs rows grouped by `product_id` (a sort, or an index scan in `product_id` order) but, unlike `RANK()`, no ordering by `year` inside the partition, so a sort only needs the partition key. In theory, with `(product_id, year, …)` indexed the data arrives already grouped. Measured, MySQL reads the index and **still sorts**, and that sort is not the expensive part anyway. There is no join and no per-row subquery. The price is that MySQL evaluates a window function by buffering the rows of each partition and visiting every row, so all rows of `Sales` pass through the window machinery, not just one entry per product. In the bench's plan at 1M rows, that *window aggregate with buffering* takes about 2.5 s, against about 0.05 s for the sort; the 1M-row result is then materialised before the `yr = first_year` filter.

### Approach 3 (optimal): `GROUP BY` then join back (`solutions/03_join_to_min_year.sql`)

```sql
SELECT s.product_id, f.first_year, s.quantity, s.price
FROM Sales s
JOIN (SELECT product_id, MIN(year) AS first_year FROM Sales GROUP BY product_id) f
  ON f.product_id = s.product_id AND f.first_year = s.year;
```

**Why it is correct:** the derived table has one row per product with the earliest year; joining back on `(product_id, year)` returns all rows of that year. Because the derived table has exactly one row per product, the join cannot duplicate rows.

**Cost model (reasoned):** two passes over `Sales`: one to aggregate (a hash or index-ordered group-by; with `(product_id, year, …)` indexed, `MIN(year)` is one index entry per product, so this pass reads only about one row per product), one to join back. Measured plans: without the index, MySQL materialises the aggregate, indexes it (`<auto_key0>`), and probes it once per `Sales` row. With the index, it inverts the join: a *skip scan* reads one entry per product for the minimum, then one index lookup per product fetches that year's rows. The aggregate has one row per product, which is small relative to `Sales`, so the second pass is the dominant cost, and it is plain hash-join work with no per-row window evaluation.

**Measured** (`gen.py` data, generated by the bench workflow; the table is filled in automatically, so never type numbers here):

<!-- BENCH:20-product-sales-analysis-iii -->
_Measured 2026-11-04 by the bench workflow: MySQL 8.0.46, AMD EPYC 7763 64-Core Processor, 2 vCPU. Median of 3 runs after 1 warm-up; each statement capped at 60 s. Sizes are main-table rows from `gen.py`. Raw numbers and EXPLAIN ANALYZE: `bench/results/20-product-sales-analysis-iii.json`._

**Without indexes**

| Solution | 1,000 rows | 100,000 rows | 1,000,000 rows | × slower than optimal @ 1,000,000 |
|---|---:|---:|---:|---:|
| `01_correlated_min` | 265 ms | timeout >60s | timeout >60s † | > 11× |
| `02_window_min_year` | 6.63 ms | 406 ms | 6.72 s | 1.2× |
| `03_join_to_min_year` (optimal) | 6.81 ms | 407 ms | 5.4 s | 1.0× |

† not run at this size: it already timed out at a smaller size.

**With `indexes.sql`**

| Solution | 1,000 rows | 100,000 rows | 1,000,000 rows | × slower than optimal @ 1,000,000 |
|---|---:|---:|---:|---:|
| `01_correlated_min` | 6.99 ms | 699 ms | 6.91 s | 1.7× |
| `02_window_min_year` | 4.46 ms | 393 ms | 6.49 s | 1.6× |
| `03_join_to_min_year` (optimal) | 4.15 ms | 381 ms | 4.03 s | 1.0× |

> GitHub-hosted runners are shared, noisy VMs: compare the ratios between rows, not the absolute times.
<!-- /BENCH -->

### Why the optimal one wins

Approach 3 splits the work into two cheap relational operations: a `MIN` aggregate (one index entry per product with `indexes.sql`, a single hash aggregate without it), and a join back that keeps only the rows whose year equals it. Approach 2 reads each row once, but MySQL runs every row of `Sales` through the window evaluation (buffering the partition), so it does more work per row. Measured at 1M rows: approach 2 is about 1.25× approach 3 without the index and 1.6× with it (at 100K rows the two are tied). The correlated form (approach 1) only finishes once the covering index exists, and is then about 1.7× approach 3. This ranking is a MySQL result, not a law. In an engine that parallelises windows well, or with no index, approach 2's single read can be the better trade, and its shape is the one that cannot be broken by a wrong join condition (`year` alone is the classic mistake). `RANK() OVER (PARTITION BY product_id ORDER BY year) = 1` returns the same rows as approach 2 (ties share rank 1) but must also order within each partition.

## 6. At scale

**(a) What breaks first.** *Measured to 1M rows, reasoned beyond:* approach 1 without an index (every row rescans the table): it times out at 100K rows. Of the other two, the one that pushes every row through a buffered window (approach 2) does more per-row work than the aggregate-and-join (approach 3). They are tied at 100K and 1.25× apart at 1M, so the gap grows with the table. The materialised aggregate is the part of approach 3 that needs memory.

**(b) One machine, ~1M–100M rows.**
- `indexes.sql` adds `Sales (product_id, year, quantity, price)`. It is *covering* (the query needs only those columns), and its order makes `MIN(year)` per product the first entry of each product's range. Measured effects: approach 3's group-by becomes a skip scan reading one index entry per product, and its join back becomes an index lookup; it gets about 25% faster and stays the fastest. Approach 1 goes from a timeout to about 7 s, because each probe becomes a short covering range read (of the whole product, not one entry). Approach 2 does not benefit: MySQL still sorts, and its cost is the buffered window.
- Do not index `year` alone: the question is per product, and a year-first index makes the per-product minimum a scan.
- `product_id`-first range partitioning does not help a query that reads every product; partition pruning only helps if a year filter is added.

**(c) Distributed engines, billions of rows. *Reasoned, not measured.***
- *Shuffle:* `MIN` is decomposable, so the join-back version (approach 3) first computes a partial minimum per product on each worker and shuffles one row per (worker, product), then broadcasts or shuffle-joins the small result back to the large side. The window version shuffles every row by `product_id` once and needs no join. Which moves less data depends on the number of products relative to the number of rows; check bytes shuffled in the query plan.
- *Skew:* a few best-selling products would give one worker most of the rows in the window plan. The pre-aggregate-then-broadcast plan removes that skew for the aggregation step.
- *Snowflake:* `QUALIFY year = MIN(year) OVER (PARTITION BY product_id)` is a single pass. If the table is clustered by `product_id`, micro-partitions hold few products each, which makes the partition-by cheap; there are no secondary indexes.
- *Things to avoid:* a global sort, and `COUNT(DISTINCT …)`. `MIN` is exact and cheap, so there is no reason for approximation.

**(d) The data-engineering answer.** The first year of a product changes rarely, and only in one direction (it can only move earlier when late-arriving data lands). Keep `product_first_year(product_id, first_year)` and update it with `LEAST`:

```sql
-- Snowflake / ANSI MERGE (UNVERIFIED): fold a new batch of Sales rows into the per-product minimum.
MERGE INTO product_first_year t
USING (SELECT product_id, MIN(year) AS batch_min FROM sales_batch GROUP BY product_id) s
ON t.product_id = s.product_id
WHEN MATCHED AND s.batch_min < t.first_year THEN UPDATE SET first_year = s.batch_min
WHEN NOT MATCHED THEN INSERT (product_id, first_year) VALUES (s.product_id, s.batch_min);

-- MySQL equivalent (no MERGE):
INSERT INTO product_first_year (product_id, first_year)
SELECT product_id, MIN(year) FROM sales_batch GROUP BY product_id
ON DUPLICATE KEY UPDATE first_year = LEAST(first_year, VALUES(first_year));

-- The report reads rows through that small table:
SELECT s.product_id, f.first_year, s.quantity, s.price
FROM Sales s JOIN product_first_year f ON f.product_id = s.product_id AND f.first_year = s.year;
```

Caveats interviewers probe: `LEAST` is safe for inserts, but **a delete or correction of the earliest year's rows is not retractable**: the new minimum has to be recomputed from the detail for the affected products. Re-applying a batch is idempotent for `LEAST` (unlike counters), which is a point in its favour.

## 7. Edge cases

Each "breaks" claim below is checked by execution: `mistakes/*.sql` are the tempting wrong queries, and the harness asserts that each one fails every dataset it names (`harness/test_mistakes.py`).

| Case | Dataset | Wrong queries it catches (`mistakes/`) |
|---|---|---|
| First years differ per product; a later year dropped; the table's overall earliest year belongs to one product | `tests/edge_typical.sql` | `global_min_year`, `first_by_sale_id`, `join_on_year_only` (other products' rows in a shared year) |
| Several rows in the first year; two rows identical except `sale_id` (output has the row twice) | `tests/edge_same_year_rows.sql` | `row_number_one` (one row per product), `distinct_collapses_duplicates`, `sum_per_product` |
| Single-row product; all rows in one year; `sale_id` reused for another product in another year (legal under the composite key) | `tests/edge_single_rows_reused_sale_id.sql` | `row_number_one`, `sum_per_product`, `global_min_year`, `first_by_sale_id` |
| `sale_id` order opposite to year order; gaps between years | `tests/edge_year_vs_sale_id.sql` | `first_by_sale_id`, `global_min_year` |
| `Sales` empty | `tests/edge_empty.sql` | none; every approach returns no rows |

No approach in `solutions/` is broken by any of these. NULLs are outside the spec; every column is `NOT NULL` in `schema.sql`.

## 8. Interviewer follow-ups

1. **"Return only one row per product."** Then ties must be broken. `ROW_NUMBER() OVER (PARTITION BY product_id ORDER BY year, sale_id)`, or aggregate (`SUM(quantity)`) if "one row" means a total. Ask which one is meant, since they are different questions.
2. **"Return the *latest* year instead."** Replace `MIN` with `MAX`. The structure does not change. For "latest row per key" with a timestamp, the same equality-with-the-extreme trick applies, with a tie-break if the timestamp is not unique (problem 21 is this in an as-of form).
3. **"Why not `RANK() OVER (PARTITION BY product_id ORDER BY year) = 1`?"** It returns the same rows. `MIN() OVER` does less work (no ordering inside the partition), `RANK` is more recognisable and generalises to "the first two years" (`DENSE_RANK() <= 2`).
4. **"Also return the total quantity sold in that first year."** Add `SUM(quantity) OVER (PARTITION BY product_id, year)` before the filter, or aggregate in a CTE and join.
5. **"What if the same product has a NULL year?"** `MIN` ignores NULLs, and `year = first_year` is never true for the NULL row, so those rows silently vanish. Decide whether they should be treated as "unknown", and say so out loud.

## 9. Snowflake notes (UNVERIFIED)

`snowflake.sql` is the window form (approach 2) with `QUALIFY`; on Snowflake there is no clustered primary key to make the aggregate cheap, so the single-pass window is the natural choice there (reasoned, UNVERIFIED). What changes, and why:

- `QUALIFY year = MIN(year) OVER (PARTITION BY product_id)` replaces the subquery and the outer filter; the window is evaluated after `WHERE` and before the projection, so the query is one `SELECT`.
- `YEAR` is also a function name in Snowflake, but it is accepted as a column name; if you prefer, quote the identifier consistently when you create the table, because unquoted names are stored upper-case.
- No secondary indexes. If `Sales` is clustered by `product_id`, each micro-partition holds few products, which makes the partition-by cheap; clustering by `year` would not help this query.
- `MIN_BY`/`MAX_BY` return one row's value per group, so they cannot return all tied rows and would not satisfy the spec.

## 10. Pattern links

Same pattern (first/last row per key, keeping every tied row):
- `16-department-highest-salary`: the mirror image with `MAX`: equality against a per-group extreme, ties kept.
- `21-product-price-at-a-given-date`: the latest row per key as of a date, with a default when none exists.
- `22-find-students-who-improved`: first *and* last row per group, compared.
- `23-game-play-analysis-iv`: the first date per player as the anchor for a cohort measure.
- `24-immediate-food-delivery-ii`: the first order per customer, then a ratio over those rows.
- `36-find-churn-risk-customers`: latest row per key compared with history.
