# 13 · Find Category Recommendation Pairs

## 1. Problem & trigger phrases

Original: [Find Category Recommendation Pairs](https://leetcode.com/problems/find-category-recommendation-pairs/) (LeetCode 3554, hard). Read the statement there; this guide only restates the spec in its own words.

**Spec (own words):** map each purchase to its product's category. For every pair of different categories, count the customers who bought at least one product in each. Report the pairs with at least 3 such customers, with `category1` alphabetically before `category2`, most popular first, ties by `category1` then `category2`.

| Trigger phrase | What it forces in SQL |
|---|---|
| "category1 < category2" | A self-join on the customer, with a **string** comparison deciding the pair's orientation. `<` both removes "pair with itself" and reports each pair once. `<=` adds `(Books, Books)`; `<>` reports every pair twice. |
| "unique customers … from both categories" | The unit counted is the **customer**, but the join works at **purchase** grain, where one customer can appear many times in the same category pair (two Books products × one Electronics product = two rows). Either `COUNT(DISTINCT user_id)` or, better, a dedupe to `(customer, category)` **before** the join. This is the whole difficulty. |
| "at least 3 different customers" | A threshold on the aggregate: `HAVING … >= 3`. Three customers must be three, not three product combinations. |

Compared with `12-find-product-recommendation-pairs`, one extra step appears: products must be translated into categories first, and several products can map to one category, which is where counting goes wrong.

## 2. Schema & grain

| Table | One row means | Columns that matter |
|---|---|---|
| `ProductPurchases` | one customer bought one product (primary key `(user_id, product_id)`) | `user_id`, `product_id`. `quantity` is irrelevant. |
| `ProductInfo` | one product | `product_id`, `category` (the mapping). `price` is irrelevant. |

**Output grain:** one row per unordered pair of categories.

**Where the grain changes:** four moves, and the order decides both correctness and cost.

1. *Purchase → (customer, category):* map product to category, then collapse "customer bought several products in this category" into one fact. This is the grain the count is made at. `(customer, category)` is the real unit of "bought something in a category".
2. *Up:* self-join `(customer, category)` on the customer. A customer with `c` categories gives `c(c−1)/2` rows, one per category pair.
3. *Down:* `GROUP BY` the category pair counts the customers.
4. *Threshold:* `HAVING`.

If you skip move 1 the join is at product grain: a customer with `n_A` products in A and `n_B` in B gives `n_A × n_B` rows for the same pair, and the count is wrong unless you add `DISTINCT`. With move 1 the count is right by construction.

## Assumptions

Confidence is `high`; the spec is silent on the following.

1. **A purchase with no category is not part of any pair.** That covers two data cases: a purchased product with no `ProductInfo` row, and a product whose `category` is NULL. Both give no category, so they are dropped at the mapping step (an inner join with `category IS NOT NULL`). They are not pooled into an invented "Unknown" category. Tested in `tests/edge_unmapped_and_null.sql`. (Problem 12 handles the opposite choice: there the pair is defined by product ids, so a missing category only blanks a column.)
2. **Categories are compared with MySQL's default collation** (`utf8mb4_0900_ai_ci`: case- and accent-insensitive). `'books'` and `'Books'` are then the same category, and `'books' < 'Books'` is false. Snowflake compares strings case-sensitively by default, so on data with inconsistent capitalisation the two engines can report different pairs (section 9). Not tested; the datasets use consistently cased names.
3. **Two customers who bought the same set of products count separately.** Customers are counted, not distinct baskets.

## 3. Hint ladder

<details><summary>Hint 1</summary>

Pattern: **self-join for pairs, but dedupe to the grain you count at first**. The pair is of categories; the thing counted is customers; products are only a stepping stone.

</details>

<details><summary>Hint 2</summary>

Shape: (1) turn purchases into distinct (customer, category) facts, (2) self-join those on the customer with `a.category < b.category`, (3) group by the two categories and count customers, (4) keep the groups with 3 or more, (5) sort.

</details>

<details><summary>Hint 3</summary>

Key clause: `SELECT DISTINCT user_id, category` in a CTE, then `JOIN cust_cat b ON b.user_id = a.user_id AND b.category > a.category`, `GROUP BY a.category, b.category HAVING COUNT(*) >= 3`. Because each customer has at most one row per category, `COUNT(*)` is exactly the customer count; no `COUNT(DISTINCT …)` is needed. If you do join at product grain, you must use `COUNT(DISTINCT user_id)`.

</details>

## 4. Decomposition

Read the output: two category names and a customer count. Nothing about products. So the first job is to get rid of products without losing the "who bought what" link.

1. **`cust_cat`: join `ProductPurchases` to `ProductInfo`, `SELECT DISTINCT user_id, category`.**
   *Why a JOIN here:* "map each purchase to its product category" is a lookup of a per-product fact. *Why DISTINCT:* "unique customers … from both categories" and "a customer buying several products in one category counts once". The grain of the rest of the query is `(customer, category)`, so create it here, where it is cheap (one pass), rather than undoing the duplicates later on a much bigger join. *Why `category IS NOT NULL`:* a product without a category is not a category (Assumption 1).
2. **`pairs`: self-join `cust_cat` on `user_id` with `b.category > a.category`.**
   *Why a self-join:* the two categories of a pair are in two different rows of the same table; the customer is the only thing linking them. *Why the string `>`:* "category1 < category2" — one comparison gives each unordered pair once and excludes a category paired with itself.
3. **`GROUP BY a.category, b.category`, `COUNT(*)`.**
   *Why a GROUP BY here:* the output is one row per pair; counting rows counts customers, because step 1 guarantees one row per customer per category.
4. **`HAVING COUNT(*) >= 3`.**
   *Why HAVING, not WHERE:* the condition is on an aggregate.
5. **`ORDER BY customer_count DESC, category1, category2`.**
   *Why all three keys:* the order is then total.

Assembled (this is `solutions/03_dedupe_then_self_join.sql`):

```sql
WITH cust_cat AS (                                    -- step 1: purchase grain -> (customer, category) grain
  SELECT DISTINCT pp.user_id, pi.category
  FROM ProductPurchases pp
  JOIN ProductInfo pi ON pi.product_id = pp.product_id
  WHERE pi.category IS NOT NULL
)
SELECT a.category AS category1, b.category AS category2,
       COUNT(*) AS customer_count                      -- step 3: one row per customer per pair
FROM cust_cat a
JOIN cust_cat b ON b.user_id = a.user_id AND b.category > a.category   -- step 2: pairs, once each
GROUP BY a.category, b.category
HAVING COUNT(*) >= 3                                   -- step 4
ORDER BY customer_count DESC, category1 ASC, category2 ASC;           -- step 5
```

Self-check: for one reported pair, pick a customer with several products in one of the two categories and confirm they add exactly 1. Search the output for a row with `category1 = category2` (there must be none) and a row with `category1 > category2` (none).

## 5. Approaches: brute force → optimal

### Approach 1: product-level self-join (`solutions/01_product_level_self_join.sql`)

```sql
SELECT i1.category AS category1, i2.category AS category2, COUNT(DISTINCT a.user_id) AS customer_count
FROM ProductPurchases a
JOIN ProductPurchases b ON b.user_id = a.user_id
JOIN ProductInfo i1 ON i1.product_id = a.product_id
JOIN ProductInfo i2 ON i2.product_id = b.product_id
WHERE i1.category < i2.category
GROUP BY i1.category, i2.category
HAVING COUNT(DISTINCT a.user_id) >= 3
ORDER BY customer_count DESC, category1, category2;
```

**Why it is correct:** the join pairs every product of a customer with every product of the same customer; the `WHERE` keeps the rows whose categories are in the right orientation (a NULL category compares as unknown and is dropped); `COUNT(DISTINCT a.user_id)` removes the duplication from multiple products per category. Correct, and the version most people write first, which is why the plain `COUNT(*)` version is the classic wrong answer here (`mistakes/count_rows_not_customers.sql`).

**Cost model (reasoned):** the join produces `n²` rows per customer (n = products bought), before any filter on category: every customer's products against all of that customer's products, including pairs in the same category and mirrored pairs, which the `WHERE` throws away afterwards. Each of those rows then costs two lookups in `ProductInfo`. `COUNT(DISTINCT)` additionally keeps a set of customers per group.

### Approach 2: map to categories first, then self-join (`solutions/02_map_then_self_join.sql`)

```sql
WITH cust_cat AS (
  SELECT pp.user_id, pi.category
  FROM ProductPurchases pp JOIN ProductInfo pi ON pi.product_id = pp.product_id
  WHERE pi.category IS NOT NULL
)
SELECT a.category AS category1, b.category AS category2, COUNT(DISTINCT a.user_id) AS customer_count
FROM cust_cat a JOIN cust_cat b ON b.user_id = a.user_id AND b.category > a.category
GROUP BY a.category, b.category
HAVING COUNT(DISTINCT a.user_id) >= 3
ORDER BY customer_count DESC, category1, category2;
```

**Why it is correct:** the same reasoning as approach 1, with the category lookup done once per purchase instead of twice per joined row. The category inequality is in the `ON`, so the pairs are already oriented when they are produced. `COUNT(DISTINCT)` is still required: `cust_cat` can hold the same `(customer, category)` several times.

**Cost model (reasoned):** the lookups got cheaper, but the self-join still multiplies duplicates: a customer with 3 products in A and 2 in B emits 6 rows for the pair (A, B). The row count is Σ over customers and category pairs of `n_A × n_B`.

### Approach 3 (optimal): dedupe to (customer, category), then self-join (`solutions/03_dedupe_then_self_join.sql`)

The SQL is the assembled query in section 4.

**Why it is correct:** after `DISTINCT` a customer has at most one row per category, so the self-join emits exactly one row per customer per oriented category pair. Counting rows is counting customers. A category with no purchases never appears. The `category IS NOT NULL` filter happens before the dedupe, so products without a category are not collapsed into a fake one.

**Cost model (reasoned):** one pass to join and deduplicate (a hash or sort on `(user_id, category)`), then a self-join whose output is bounded by `Σ c(c−1)/2` with `c` = distinct categories per customer. Categories are few compared with products, so `c` is much smaller than `n` and the quadratic term hits a much smaller number. There is no `COUNT(DISTINCT)` bookkeeping. Unlike problem 12, pre-pruning rare *categories* is unlikely to help here, because a catalogue has few categories and most are common.

**Measured** (`gen.py` data, generated by the bench workflow; the table is filled in automatically, so never type numbers here):

<!-- BENCH:13-find-category-recommendation-pairs -->
_Measured 2026-11-04 by the bench workflow: MySQL 8.0.46, Intel(R) Xeon(R) Platinum 8370C CPU @ 2.80GHz, 2 vCPU. Median of 3 runs after 1 warm-up; each statement capped at 60 s. Sizes are main-table rows from `gen.py`. Raw numbers and EXPLAIN ANALYZE: `bench/results/13-find-category-recommendation-pairs.json`._

**Without indexes**

| Solution | 1,000 rows | 100,000 rows | 1,000,000 rows | × slower than optimal @ 1,000,000 |
|---|---:|---:|---:|---:|
| `01_product_level_self_join` | 13.5 ms | 1.21 s | 12.8 s | 1.2× |
| `02_map_then_self_join` | 14.1 ms | 1.26 s | 13.4 s | 1.3× |
| `03_dedupe_then_self_join` (optimal) | 3.08 ms | 310 ms | 10.4 s | 1.0× |

**With `indexes.sql`**

| Solution | 1,000 rows | 100,000 rows | 1,000,000 rows | × slower than optimal @ 1,000,000 |
|---|---:|---:|---:|---:|
| `01_product_level_self_join` | 13.8 ms | 1.2 s | 12.8 s | 1.2× |
| `02_map_then_self_join` | 14.4 ms | 1.26 s | 13.3 s | 1.3× |
| `03_dedupe_then_self_join` (optimal) | 3.13 ms | 309 ms | 10.3 s | 1.0× |

> GitHub-hosted runners are shared, noisy VMs: compare the ratios between rows, not the absolute times.
<!-- /BENCH -->

### Why the optimal one wins

All three give the same answer. They differ in *what grain the self-join runs at*. Approach 1 joins at product × product, approach 2 at purchase × purchase after mapping, approach 3 at category × category after deduplication, the grain the question is asked at. Deduplicating **before** a row-multiplying join is cheaper and safer than deduplicating after it, and that principle applies far beyond this problem.

## 6. At scale

**(a) What breaks first.** *Reasoned, then checked by the bench table:* approach 1, because its join size is the sum of squared basket sizes, with two dimension lookups per joined row. Approach 2 next: still duplicate-multiplying. Approach 3 last: its join size depends on the number of categories per customer, which is small and bounded by the number of categories.

**(b) One machine, ~1M–100M rows.**
- The `DISTINCT` needs a temporary table or a sort keyed by `(user_id, category)`. With `ProductPurchases` clustered by `(user_id, product_id)`, a customer's rows are already adjacent, so MySQL can deduplicate while streaming if the category lookup is cheap. `indexes.sql` adds `ProductInfo (product_id, category)` so that lookup is answered from an index without row access.
- If the mapping changes rarely, materialise `(user_id, category)` as its own table (see (d)). Every later question on categories then starts at step 2.
- A customer with hundreds of categories produces a quadratic number of rows; cap or exclude outliers when exploring.
- Mind the collation (Assumption 2): grouping and comparison follow the column's collation, so mixed-case category names silently merge in MySQL.

**(c) Distributed engines, billions of rows. *Reasoned, not measured.***
- *Shuffle:* the dedupe `(user_id, category)` is a shuffle by customer (or, with map-side distinct, a much smaller shuffle). The self-join is also keyed by customer, so one shuffle can serve both if data is partitioned by `user_id`. The `ProductInfo` join is a broadcast (small dimension).
- *Why dedupe before the join matters more here:* the join's output is what gets shuffled again for the `GROUP BY (category1, category2)`. A smaller join output means less shuffle data; fan-out is the thing that blows up a distributed plan.
- *Skew:* a handful of customers with very many categories. Cap them. And a few very popular category pairs: partial aggregation by pair removes that skew.
- *Distinct counts:* approach 3 converts `COUNT(DISTINCT user_id)` into a deduplicate + `COUNT(*)`, which is a plain decomposable aggregate. `COUNT(DISTINCT)` per group can't pre-aggregate to a single number per task. An approximate distinct count (HyperLogLog) is acceptable for ranking pairs on a dashboard, but not for the exact cut-off at 3.
- *Pruning:* none by date or key here; the whole table is read.

**(d) The data-engineering answer.** Persist the deduplicated fact table and maintain it incrementally. `cust_cat(user_id, category)` is an idempotent set (a customer either has bought in a category or has not), which makes incremental maintenance easy: inserting an existing pair changes nothing.

```sql
-- cust_cat(user_id, category, PRIMARY KEY (user_id, category)); category_pair_counts(category1, category2, customer_count)
-- Snowflake / ANSI MERGE (UNVERIFIED), run per batch of new purchases:
-- 1) new (customer, category) facts, those not already known
CREATE OR REPLACE TEMPORARY TABLE new_facts AS
SELECT DISTINCT pb.user_id, pi.category
FROM purchases_batch pb JOIN ProductInfo pi ON pi.product_id = pb.product_id
WHERE pi.category IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM cust_cat c WHERE c.user_id = pb.user_id AND c.category = pi.category);

-- 2) pairs those facts create: new x existing, and new x new (each pair once)
MERGE INTO category_pair_counts t
USING (
  SELECT category1, category2, SUM(c) AS c FROM (
    SELECT LEAST(n.category, o.category) AS category1, GREATEST(n.category, o.category) AS category2, COUNT(*) AS c
    FROM new_facts n JOIN cust_cat o ON o.user_id = n.user_id AND o.category <> n.category
    GROUP BY 1, 2
    UNION ALL
    SELECT a.category, b.category, COUNT(*)
    FROM new_facts a JOIN new_facts b ON b.user_id = a.user_id AND b.category > a.category
    GROUP BY 1, 2) d
  GROUP BY category1, category2) s
ON t.category1 = s.category1 AND t.category2 = s.category2
WHEN MATCHED THEN UPDATE SET customer_count = t.customer_count + s.c
WHEN NOT MATCHED THEN INSERT (category1, category2, customer_count) VALUES (s.category1, s.category2, s.c);

-- 3) finally INSERT new_facts INTO cust_cat. Read side: SELECT ... FROM category_pair_counts WHERE customer_count >= 3.
```

Caveats interviewers probe. *Idempotency*: step 1's `NOT EXISTS` is what makes a replayed batch a no-op (the second time, nothing is new). *Deletes and refunds*: a customer stops being in a category only when their *last* product in it is removed, which needs a per-(customer, category) purchase count, not a set. *Remaps*: if a product changes category, every customer who bought it changes facts; recompute the affected customers.

## 7. Edge cases

Each "breaks" claim below is checked by execution: `mistakes/*.sql` are the tempting wrong queries, and the harness asserts that each one fails every dataset it names (`harness/test_mistakes.py`).

| Case | Dataset | Wrong queries it catches (`mistakes/`) |
|---|---|---|
| Customer with several products in one category (fan-out) | `tests/edge_typical.sql` | `count_rows_not_customers` (counts 4, not 3) |
| Fan-out alone pushing a pair over the threshold (2 customers, 8 product-level rows) | `tests/edge_fanout_below_threshold.sql` | `count_rows_not_customers` |
| A category paired with itself; customers with one category only | `tests/edge_typical.sql`, `tests/edge_single_category.sql` | `same_category_pairs` |
| Mirrored pairs / wrong orientation | `tests/edge_typical.sql`, `tests/edge_threshold.sql`, `tests/edge_ordering.sql`, `tests/edge_unmapped_and_null.sql` | `mirror_pairs`, `reversed_pair` |
| Exactly 3 customers, exactly 2 | `tests/edge_threshold.sql`, `tests/edge_typical.sql` | `threshold_greater_than_3` |
| Product with no `ProductInfo` row; product with NULL category | `tests/edge_unmapped_and_null.sql` | `unknown_as_category` (invents an 'Unknown' category) |
| Id order opposite to alphabetical order; ties on count; ties within a `category1` | `tests/edge_ordering.sql` | `second_category_first_ordering`, `count_ascending` |
| No purchases | `tests/edge_empty.sql` | none |

No approach in `solutions/` is broken by any of these.

## 8. Interviewer follow-ups

1. **"Why is `COUNT(DISTINCT user_id)` slower than your version?"** It has to remember which customers it has seen in each group (a hash set per group) and it cannot be partially aggregated to a single number per worker. Deduplicating once up front turns it into `COUNT(*)`. The cost moves to the `DISTINCT`, which is a single pass and parallel.
2. **"How is this different from the product version?"** The pair is of categories, so the unit counted (a customer) can reach the same pair through several product combinations. Problem 12 has a unique `(customer, product)` pair, so each customer contributes at most one row per product pair and no dedupe is needed.
3. **"Give me the top category for each customer instead."** A different shape: group by (customer, category), rank within customer with `ROW_NUMBER`, take rank 1, decide how to break ties. See `19-department-top-three-salaries` for the ranking pattern.
4. **"Triples of categories?"** A third self-join; with few categories the number of triples is small, but the join output per customer is `c³`. Prune pairs below the threshold first.
5. **"Categories are hierarchical (Books → Fiction → Sci-Fi)."** Map to the level the question needs before step 1, or add the level to the mapping. Every ancestor adds a category for each product, which creates new fan-out inside the same customer, and the dedupe handles that for free.
6. **"Why is it correct to drop products with no category?"** It is a data-quality decision, not a SQL one. State it, count how many purchases it affects, and mention it. Inventing an 'Unknown' category would create recommendations of the form (X, Unknown) that nobody can act on.

## 9. Snowflake notes (UNVERIFIED)

`snowflake.sql` keeps the shape of approach 3.

- **String comparison is case-sensitive by default in Snowflake**, and `'Books' < 'books'` is true there (uppercase sorts before lowercase in binary collation). On clean data the result matches MySQL's; on mixed-case data it will not. If you need MySQL-like behaviour, normalise with `LOWER(category)` in the CTE or use `COLLATE 'en-ci'`.
- `SELECT DISTINCT` and the self-join are the same SQL. The optimiser may rewrite the dedupe as a group-by; check the profile for the size of the self-join output, which is the cost centre.
- `ARRAY_AGG(DISTINCT category)` per customer plus a lateral flatten is an alternative to the self-join when baskets are small. It trades a join for an array per customer.
- No indexes; `indexes.sql` has no equivalent. A small `ProductInfo` is broadcast automatically.
- Unquoted identifiers are returned upper-cased (`CATEGORY1`).

## 10. Pattern links

Same pattern (self-join to form pairs, count distinct entities):
- `12-find-product-recommendation-pairs`: the product version; no dedupe step needed there because `(customer, product)` is unique.
- `27-most-common-course-pairs`: another pairs-counted-across-people problem (courses instead of categories).

Related (deduplicate before a multiplying step):
- `40-friend-requests-ii-who-has-the-most-friends`: a relationship stored once but counted from both ends, which needs the same "get the grain right first" treatment.
- `14-customers-who-bought-all-products`: `COUNT(DISTINCT …)` against a target count when the table may repeat.
