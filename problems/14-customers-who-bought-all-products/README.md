# 14 · Customers Who Bought All Products

## 1. Problem & trigger phrases

Original: [Customers Who Bought All Products](https://leetcode.com/problems/customers-who-bought-all-products/) (LeetCode 1045, medium). Read the statement there; this guide only restates the spec in its own words.

**Spec (own words):** `Customer` holds purchase rows (customer, product), possibly repeated. `Product` lists every product that exists. Return the ids of customers who have bought every product in `Product`. Any order.

| Trigger phrase | What it forces in SQL |
|---|---|
| "bought all the products" | **Relational division**: "for all x in A, there exists a matching row in B". There are two standard encodings. *Counting:* the number of distinct products the customer bought equals the number of products that exist (`COUNT(DISTINCT product_key) = (SELECT COUNT(*) FROM Product)`). *Double negation:* there is no product for which there is no purchase (`NOT EXISTS (… NOT EXISTS …)`). The comparison involves two different grains: a per-customer count against a whole-table count. |
| "may contain duplicate rows" | Rows are not the unit; **distinct products** are. Counting rows (`COUNT(*)`, `COUNT(product_key)`) is wrong in both directions: repeats can fake a full set, and repeats can break an `=` check for a customer who really did buy everything. Use `DISTINCT`. |
| "all the products" (not "3 products") | The target is a *query result*, `(SELECT COUNT(*) FROM Product)`, never a literal. |

## 2. Schema & grain

| Table | One row means | Columns that matter |
|---|---|---|
| `Customer` | one purchase of one product by one customer; exact repeats allowed (no primary key) | `customer_id`, `product_key` |
| `Product` | one product that exists | `product_key` |

**Output grain:** one row per qualifying customer, each at most once.

**Where the grain changes:** purchase rows → one row per customer, by `GROUP BY customer_id`. The new feature compared with the earlier problems is that the filter compares a *group-level* quantity (distinct products of this customer) with a *table-level* scalar (the number of products). Table-level scalars are what a scalar subquery in `HAVING` is for.

## Assumptions

Confidence is `high`; the spec does not say the following, so the guide fixes them and the datasets check them.

1. **A NULL `product_key` is not a product.** The column is nullable (a foreign key allows NULL). A NULL row is a purchase of nothing and counts toward no product. `COUNT(DISTINCT product_key)` ignores NULL; a "dedupe then `COUNT(*)`" would count it. Tested in `tests/edge_null_product_key.sql`.
2. **The foreign key holds.** The spec says every `product_key` in `Customer` exists in `Product`. The counting approach (03) *depends* on that: if a customer could hold a key that is not in `Product`, then their distinct count could reach the total while one real product is missing. Approaches 1 and 2 do not depend on it. The datasets and `gen.py` never violate it, so they cannot test it; follow-up 3 covers the repair.
3. **`Product` is not empty.** The spec says an empty `Product` is not tested. For the record, the approaches disagree there (vacuous truth): approaches 1 and 3 return every customer (with no products to find missing, all qualify), approach 2 returns no one (an empty grid). Nothing in `tests/` or `gen.py` creates this state.

## 3. Hint ladder

<details><summary>Hint 1</summary>

Pattern: **relational division**, "customers who have done *all* of X". Counting form: compare a customer's number of distinct matches with the total number of X.

</details>

<details><summary>Hint 2</summary>

Shape: (1) group the purchases by customer, (2) for each customer count the *distinct* products, (3) compare with the number of rows in `Product`, (4) keep the customers whose counts are equal.

</details>

<details><summary>Hint 3</summary>

Key clause: `GROUP BY customer_id HAVING COUNT(DISTINCT product_key) = (SELECT COUNT(*) FROM Product)`. The `DISTINCT` is there because of duplicate rows; the scalar subquery is there because the total must not be hard-coded. The alternative with no counting is `NOT EXISTS (product with NOT EXISTS (purchase by this customer))`.

</details>

## 4. Decomposition

Read the sentence as a rule about sets: "the set of products the customer bought contains the set of all products". With the FK guarantee, "contains" reduces to "has the same size".

1. **Total: `(SELECT COUNT(*) FROM Product)`.**
   *Why a scalar subquery:* "all the products" is a property of the whole `Product` table, not of any customer. It is one number, computed once, and it must not be written as a literal.
2. **Per customer: `GROUP BY customer_id`, `COUNT(DISTINCT product_key)`.**
   *Why a GROUP BY, and why DISTINCT:* the answer is per customer, so purchase rows collapse to one row per customer. "May contain duplicate rows" means the same product can appear many times, so count distinct products. (`COUNT(DISTINCT x)` also skips NULL, which is what Assumption 1 wants.)
3. **Compare: `HAVING <per-customer count> = <total>`.**
   *Why HAVING, and why `=` is enough:* the condition is on an aggregate. Distinct purchased products are a subset of `Product` (FK), so a subset with the full size is the whole set; there is no `>` case.

Assembled (this is `solutions/03_count_distinct_equals_total.sql`):

```sql
SELECT customer_id
FROM Customer
GROUP BY customer_id                                                 -- step 2: purchase grain -> customer grain
HAVING COUNT(DISTINCT product_key) = (SELECT COUNT(*) FROM Product); -- steps 2 + 3 with step 1's scalar
```

Self-check: choose a customer with repeated rows and recount their distinct products by hand. Choose a customer who bought exactly (total − 1) products with many repeats and confirm they are absent. Then replace the `DISTINCT` and watch which of the two checks breaks.

## 5. Approaches: brute force → optimal

### Approach 1: double `NOT EXISTS` (`solutions/01_double_not_exists.sql`)

```sql
SELECT c.customer_id
FROM (SELECT DISTINCT customer_id FROM Customer) c
WHERE NOT EXISTS (
  SELECT 1 FROM Product p
  WHERE NOT EXISTS (
    SELECT 1 FROM Customer x
    WHERE x.customer_id = c.customer_id AND x.product_key = p.product_key));
```

**Why it is correct:** it is the definition of division. A customer is excluded as soon as some product has no purchase row by them; the customers left are those with no such product. Duplicates and NULL keys are harmless: the innermost query only asks whether a row exists. It does not rely on the foreign key. It is the "natural" first attempt for anyone who thinks in logic: "all" is "no counter-example".

**Cost model (reasoned):** for each customer, loop over products, and for each pair probe the purchases. That is customers × products probes in the worst case. Each probe is a scan of `Customer` unless the `indexes.sql` index `(customer_id, product_key)` exists, in which case it is a point lookup. MySQL often turns such a `NOT EXISTS` into an anti-join, but a nested one still gives work proportional to the grid size.

### Approach 2: build the grid, count the holes (`solutions/02_grid_with_holes.sql`)

```sql
WITH bought AS (SELECT DISTINCT customer_id, product_key FROM Customer),
     grid AS (SELECT c.customer_id, p.product_key
              FROM (SELECT DISTINCT customer_id FROM Customer) c CROSS JOIN Product p)
SELECT g.customer_id
FROM grid g LEFT JOIN bought b ON b.customer_id = g.customer_id AND b.product_key = g.product_key
GROUP BY g.customer_id
HAVING COUNT(b.product_key) = COUNT(*);
```

**Why it is correct:** the grid has one cell for every (customer, product) combination. The LEFT JOIN fills the cells that were bought; an unfilled cell has a NULL `b.product_key`. `COUNT(*)` counts all cells of a customer, `COUNT(b.product_key)` counts the filled ones; they are equal exactly when there is no hole. `bought` is deduplicated so that repeated purchases cannot make a cell appear twice. This is the scaffold-and-LEFT-JOIN pattern of problem 09, applied to a matrix.

**Cost model (reasoned):** it materialises or streams customers × products grid rows, regardless of how few purchases there are, then joins and groups them. For 1M customers and 20 products that is 20M grid rows. It pays for the empty cells, which approach 3 never visits.

### Approach 3 (optimal): distinct count equals total (`solutions/03_count_distinct_equals_total.sql`)

The SQL is the assembled query in section 4.

**Why it is correct:** the foreign key makes each customer's distinct products a subset of `Product`; a subset has the full size only if it is the full set. `COUNT(DISTINCT product_key)` ignores repeats and NULLs. The subquery supplies the live total, so adding a product changes the answer without editing the query.

**Cost model (reasoned):** one scan of `Customer`, one `GROUP BY customer_id` that tracks the set of distinct keys per customer, and one tiny scalar subquery that is evaluated once (it is not correlated). Work is proportional to the number of purchase rows. With `indexes.sql` the rows arrive grouped by `customer_id` and sorted by `product_key`, so the distinct count is a streaming "count changes" with no hash set and no temporary table.

**Measured** (`gen.py` data, generated by the bench workflow; the table is filled in automatically, so never type numbers here):

<!-- BENCH:14-customers-who-bought-all-products -->
_Measured 2026-11-04 by the bench workflow: MySQL 8.0.46, Intel(R) Xeon(R) Platinum 8370C CPU @ 2.80GHz, 2 vCPU. Median of 3 runs after 1 warm-up; each statement capped at 60 s. Sizes are main-table rows from `gen.py`. Raw numbers and EXPLAIN ANALYZE: `bench/results/14-customers-who-bought-all-products.json`._

**Without indexes**

| Solution | 1,000 rows | 100,000 rows | 1,000,000 rows | × slower than optimal @ 1,000,000 |
|---|---:|---:|---:|---:|
| `01_double_not_exists` | 83 ms | timeout >60s | timeout >60s † | > 102× |
| `02_grid_with_holes` | 3.22 ms | 298 ms | 7.18 s | 12.2× |
| `03_count_distinct_equals_total` (optimal) | 1.37 ms | 59.2 ms | 588 ms | 1.0× |

† not run at this size: it already timed out at a smaller size.

**With `indexes.sql`**

| Solution | 1,000 rows | 100,000 rows | 1,000,000 rows | × slower than optimal @ 1,000,000 |
|---|---:|---:|---:|---:|
| `01_double_not_exists` | 2.62 ms | 190 ms | 2 s | 4.3× |
| `02_grid_with_holes` | 2.89 ms | 262 ms | 5.64 s | 12.2× |
| `03_count_distinct_equals_total` (optimal) | 1.29 ms | 47.6 ms | 461 ms | 1.0× |

> GitHub-hosted runners are shared, noisy VMs: compare the ratios between rows, not the absolute times.
<!-- /BENCH -->

### Why the optimal one wins

Approach 3 does work proportional to the purchases that exist; approaches 1 and 2 do work proportional to the purchases that *could* exist (customers × products). It also states the idea at the level of the problem ("how many distinct products, against how many exist"). The price is one assumption (the foreign key). If that assumption is in doubt, either join to `Product` before counting (`JOIN Product p ON p.product_key = c.product_key`) or use approach 1, which does not depend on it.

## 6. At scale

**(a) What breaks first.** *Reasoned, then checked by the bench table:* approach 2, because the grid is customers × products regardless of the data. Approach 1 comes next if the probes are not indexed: customers × products scans of `Customer`. Approach 3 scales with purchases.

**(b) One machine, ~1M–100M rows.**
- `Customer` has no primary key (duplicates are allowed), so without help it is a heap. `indexes.sql` adds `(customer_id, product_key)`, which is covering for all three approaches. It makes the distinct count streamable, and each `NOT EXISTS` probe a point lookup.
- Deduplicating `Customer` into a table with a primary key `(customer_id, product_key)` removes the need for `DISTINCT` altogether and lets `COUNT(*)` replace `COUNT(DISTINCT)`; do it once at load time if the duplicates are an ingestion artefact.
- The total `(SELECT COUNT(*) FROM Product)` is a one-time cost. If `Product` is large, keep the count in a small table or use the table statistics only if exactness is not required (it is, here).

**(c) Distributed engines, billions of rows. *Reasoned, not measured.***
- *Shuffle:* `GROUP BY customer_id` shuffles purchases by customer. A `COUNT(DISTINCT)` does not pre-aggregate into a single number per task: the partial result must carry the set of distinct products, and a global distinct is more expensive than `COUNT`. Because the number of products is small, those sets are small (at most one entry per product), so the engine's rewrite "distinct first, then count" (group by `(customer, product)`, then by `customer`) is cheap. Spark and Snowflake both do some version of it.
- *Skew:* a customer with an enormous number of rows (a test account) overloads one reducer. Deduplicating `(customer, product)` first with a map-side combine reduces it to at most one row per product per task.
- *Joins:* `Product` is small and is broadcast. The grid approach multiplies the largest table by the broadcast one: avoid it at this scale.
- *Approximate functions:* `APPROX_COUNT_DISTINCT` is **not** acceptable. The query is an equality test on a count; a 1% error in the count turns qualifying customers into non-qualifying ones, and vice versa. Use exact distinct counts, or the double negation.
- *Pruning:* purchases are not filtered by date here. A "bought all products in 2024" variant would filter first, and then partition pruning applies.

**(d) The data-engineering answer.** Keep a per-customer set of products bought, deduplicated, and count it incrementally. Duplicates are free to ignore: inserting an existing `(customer, product)` pair changes nothing, which makes the pipeline idempotent.

```sql
-- customer_product(customer_id, product_key, PRIMARY KEY (customer_id, product_key));  product_count_total derived from Product
-- Snowflake / ANSI MERGE (UNVERIFIED): insert only pairs not yet present (replays are no-ops).
MERGE INTO customer_product t
USING (SELECT DISTINCT customer_id, product_key FROM customer_batch WHERE product_key IS NOT NULL) s
ON t.customer_id = s.customer_id AND t.product_key = s.product_key
WHEN NOT MATCHED THEN INSERT (customer_id, product_key) VALUES (s.customer_id, s.product_key);

-- MySQL equivalent:  INSERT IGNORE INTO customer_product SELECT DISTINCT customer_id, product_key FROM customer_batch WHERE product_key IS NOT NULL;

-- Read side: a count on a deduplicated table, still compared with the live total.
SELECT customer_id FROM customer_product
GROUP BY customer_id
HAVING COUNT(*) = (SELECT COUNT(*) FROM Product);
```

Caveats interviewers probe. *New products:* when a product is added, every customer's condition changes at once, which is why the total is read live rather than stored per customer. *Product retirement:* decide whether purchases of retired products still count (the FK assumption again). *Refunds:* a refund must only remove the pair when it was the last purchase of that product by that customer, so keep a purchase count, not just a set.

## 7. Edge cases

Each "breaks" claim below is checked by execution: `mistakes/*.sql` are the tempting wrong queries, and the harness asserts that each one fails every dataset it names (`harness/test_mistakes.py`).

| Case | Dataset | Wrong queries it catches (`mistakes/`) |
|---|---|---|
| Repeated rows give as many rows as products but fewer products | `tests/edge_duplicates.sql` | `count_without_distinct`, `at_least_as_many_rows` |
| A customer who bought everything *plus* a repeat has more rows than products | `tests/edge_typical.sql` | `count_without_distinct` (the `=` rejects them) |
| A NULL `product_key` row | `tests/edge_null_product_key.sql` | `distinct_rows_count_star` (counts the NULL as a product), `not_in_with_null` (`NOT IN` against a NULL is never true) |
| `Product` with a single row (target count is not 3) | `tests/edge_single_product.sql` | `hardcoded_total` |
| Nobody bought everything, some with many rows | `tests/edge_none_qualify.sql` | `any_matching_product` (returns every buyer), `at_least_as_many_rows` |
| Customers who bought something but not everything (partial sets) | `tests/edge_typical.sql` | `any_matching_product` |
| No purchases | `tests/edge_empty_customer.sql` | none |

No approach in `solutions/` is broken by any of these. (An empty `Product` table is not tested; see Assumptions.)

## 8. Interviewer follow-ups

1. **"Customers who bought every product in a given category / in the last 30 days."** The "all" is now a *filtered* set: the total becomes `(SELECT COUNT(*) FROM Product WHERE category = …)` and the purchases are restricted to the same set (join them to the filtered products). The two sides must be restricted identically or the equality fails.
2. **"Per group: employees who have every skill required by their role."** That is `15-employees-qualified-for-every-required-skill-of-a-role`: the target set depends on the group, so the global scalar is replaced by a per-role count and a join. The same counting trick, with one more grain.
3. **"What if the foreign key is not enforced?"** Count only keys that are real products: `JOIN Product p ON p.product_key = c.product_key` before `COUNT(DISTINCT p.product_key)`. Or use the double `NOT EXISTS`, which has no such assumption.
4. **"Which products is each near-miss customer missing?"** The grid approach answers it directly (the unfilled cells), which is the reason to know it: `HAVING COUNT(b.product_key) = COUNT(*) - 1` finds customers missing exactly one, and listing the NULL cells names the products.
5. **"Why not `COUNT(*) >= total` to be safe with duplicates?"** Duplicates can supply the count without supplying the products (`mistakes/at_least_as_many_rows.sql`). The test has to be on distinct products.
6. **"How would this look with a window function?"** It would not: this is a membership/containment question, and aggregating is the natural tool. Reaching for windows here is a sign the grain is wrong.

## 9. Snowflake notes (UNVERIFIED)

`snowflake.sql` is the same query as approach 3.

- `COUNT(DISTINCT …)` is exact in Snowflake. `APPROX_COUNT_DISTINCT` (HyperLogLog) exists and is tempting, but it is wrong for an equality test. Do not use it here.
- There is no `QUALIFY` involvement; `HAVING` with a scalar subquery works as in MySQL.
- Primary and foreign keys in Snowflake are metadata only and are **not enforced** (except `NOT NULL`). The foreign-key assumption behind approach 3 is therefore a data-quality contract, not a guarantee. On Snowflake the join-to-`Product` variant (follow-up 3) is worth its small cost.
- No indexes; `indexes.sql` has no equivalent. Cost is bytes scanned of two columns plus the shuffle of the distinct step.
- Unquoted identifiers are returned upper-cased (`CUSTOMER_ID`).

## 10. Pattern links

Same pattern (relational division, count distinct equals total):
- `15-employees-qualified-for-every-required-skill-of-a-role`: division where the target set depends on a group (role), with the double-`NOT EXISTS` form.

Related:
- `11-analyze-subscription-conversion`: "has both of two specific values", the smallest case of division (the target set has two members).
- `09-count-salary-categories`: the scaffold-and-LEFT-JOIN idea used by approach 2.
