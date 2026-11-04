# 12 · Find Product Recommendation Pairs

## 1. Problem & trigger phrases

Original: [Find Product Recommendation Pairs](https://leetcode.com/problems/find-product-recommendation-pairs/) (LeetCode 3521, medium). Read the statement there; this guide only restates the spec in its own words.

**Spec (own words):** `ProductPurchases` lists which customer bought which product. Find every unordered pair of different products that were bought by the same customer, count how many distinct customers bought both, and keep the pairs with at least 3 customers. Report each pair once (smaller product id first) with both products' categories, ordered by customer count (highest first), then by the two ids.

| Trigger phrase | What it forces in SQL |
|---|---|
| "product1_id < product2_id" | The pair is made by joining the table **to itself**, and the `<` is both the "different products" test and the "report each pair once" test. `<>` finds every pair twice, no condition at all adds self-pairs `(p, p)`. |
| "how many customers purchased both" | The pair's measure is a count of customers, so `GROUP BY (product1, product2)` with `COUNT(DISTINCT user_id)`. "Same customer" is the join key of the self-join: `b.user_id = a.user_id`. Leave that out and the join pairs strangers. |
| "at least 3 different customers" | A condition on an aggregate, so `HAVING … >= 3` (not `>`, not `WHERE`). The same threshold also holds for each single product, which suggests pruning before the join (approach 2). |

Not in the wording but forced by it: attaching categories needs `ProductInfo` **twice**, once for each product of the pair, each under its own alias.

## 2. Schema & grain

| Table | One row means | Columns that matter |
|---|---|---|
| `ProductPurchases` | one customer bought one product (primary key `(user_id, product_id)`) | `user_id`, `product_id`. `quantity` is irrelevant. |
| `ProductInfo` | one product | `product_id`, `category`. `price` is irrelevant. |

**Output grain:** one row per product **pair**, i.e. per unordered `(product_id, product_id)`, not per customer and not per product.

**Where the grain changes:** this is the first problem in the repo where the grain goes **up** before it goes down.

1. *Up:* joining `ProductPurchases` to itself on the customer turns one row per (customer, product) into one row per (customer, product, product). A customer with `k` products yields `k(k−1)/2` rows. That row explosion is the cost centre of the whole problem.
2. *Down:* `GROUP BY` the two product ids collapses the customers, leaving one row per pair with a count.
3. *Sideways:* the category lookups attach per-product facts to the surviving pairs.

Because `(user_id, product_id)` is the primary key, a customer cannot appear twice for the same pair, so `COUNT(*)` and `COUNT(DISTINCT user_id)` agree here. The `DISTINCT` is protection for the case where the table is really an event log (see follow-ups); `13-find-category-recommendation-pairs` is where it becomes necessary.

## Assumptions

Confidence is `high`; the spec is silent on the following.

1. **A row in `ProductPurchases` means "bought", whatever the quantity.** The spec says quantity is irrelevant, so a row with quantity 0 still counts. Tested in `tests/edge_typical.sql`.
2. **A pair qualifies on customer count alone.** If one product of a qualifying pair has no `ProductInfo` row, the pair is still reported, with a NULL category for that product. Silently dropping a qualifying pair because a dimension row is missing would hide a data problem. Tested in `tests/edge_unknown_product.sql`. (On clean data the two readings give identical output.)
3. **Two products may share a category.** The pair `(Books, Books)` is a normal row for this problem (unlike problem 13, where categories are distinct by definition). Tested in `tests/edge_threshold.sql`.

## 3. Hint ladder

<details><summary>Hint 1</summary>

Pattern: **self-join for pairs, then count and threshold**. You are counting co-occurrences: how often two products show up for the same customer.

</details>

<details><summary>Hint 2</summary>

Shape: (1) join the purchases table to itself on the customer, keeping only rows where the first product id is smaller than the second, (2) group by the two ids and count distinct customers, (3) keep groups with 3 or more, (4) look up both categories, (5) sort.

</details>

<details><summary>Hint 3</summary>

Key clause: `JOIN ProductPurchases b ON b.user_id = a.user_id AND b.product_id > a.product_id`. Both conditions belong in the `ON`. Then `GROUP BY a.product_id, b.product_id HAVING COUNT(DISTINCT a.user_id) >= 3`. Join `ProductInfo` last, once per side. (A product with fewer than 3 customers can never be in a qualifying pair, so you could filter such products out before the join; approach 2 tries that, and it has to be measured, not assumed.)

</details>

## 4. Decomposition

Read the output left to right: two product ids, their categories, a customer count. The ids and the count come from the self-join; the categories are lookups that belong at the end.

1. **Self-join `ProductPurchases` on `user_id` with `b.product_id > a.product_id`.**
   *Why a self-join:* the two products of a pair live in two different rows of the same table, and the only thing relating them is the customer. *Why `>`:* it makes each unordered pair appear once and never pairs a product with itself. This is where the grain goes **up**: a customer with `k` products yields `k(k−1)/2` rows.
2. **`GROUP BY a.product_id, b.product_id`, `COUNT(DISTINCT a.user_id)`.**
   *Why a GROUP BY here:* the answer is a count of customers per pair; the grain goes **down** to one row per pair. `DISTINCT` is protection that costs nothing here, because `(user_id, product_id)` is a key (follow-up 5).
3. **`HAVING COUNT(DISTINCT a.user_id) >= 3`.**
   *Why HAVING, not WHERE:* "at least 3 different customers" is a condition on an aggregate.
4. **Final: `pairs LEFT JOIN ProductInfo` twice.**
   *Why two joins, and why after:* each pair has two products, so there are two lookups, one per role. Doing them after `HAVING` means they run on the few surviving pairs instead of on every exploded row. `LEFT` so that a qualifying pair is not lost for want of a category (Assumption 2).
5. **`ORDER BY customer_count DESC, product1_id, product2_id`.**
   *Why explicit and complete:* the three keys make the order total, so there are no ties left to chance.

Assembled (this is `solutions/03_self_join_group_by.sql`):

```sql
WITH pairs AS (
  SELECT a.product_id AS product1_id, b.product_id AS product2_id,
         COUNT(DISTINCT a.user_id) AS customer_count
  FROM ProductPurchases a
  JOIN ProductPurchases b ON b.user_id = a.user_id AND b.product_id > a.product_id   -- step 1: grain up
  GROUP BY a.product_id, b.product_id                                                -- step 2: grain down
  HAVING COUNT(DISTINCT a.user_id) >= 3                                              -- step 3
)
SELECT p.product1_id, p.product2_id,                                                 -- step 4: lookups on survivors only
       c1.category AS product1_category, c2.category AS product2_category, p.customer_count
FROM pairs p
LEFT JOIN ProductInfo c1 ON c1.product_id = p.product1_id
LEFT JOIN ProductInfo c2 ON c2.product_id = p.product2_id
ORDER BY p.customer_count DESC, p.product1_id ASC, p.product2_id ASC;                -- step 5
```

An optional step 0 shortens the join's input: since a qualifying pair needs 3 customers, each of its products needs at least 3 customers on its own, so rows of rarer products can be dropped first (approach 2). It does not change the answer.

Self-check: for one reported pair, list the customers who bought both by hand and confirm the count. For a product you know has only two buyers, confirm it appears in no row. Confirm there is no row with `product1_id >= product2_id`.

## 5. Approaches: brute force → optimal

### Approach 1: enumerate every pair, count each with a subquery (`solutions/01_enumerate_pairs_and_count.sql`)

```sql
SELECT q.product1_id, q.product2_id, c1.category AS product1_category, c2.category AS product2_category, q.customer_count
FROM (
  SELECT pr.p1 AS product1_id, pr.p2 AS product2_id,
         (SELECT COUNT(DISTINCT x.user_id)
            FROM ProductPurchases x JOIN ProductPurchases y ON y.user_id = x.user_id
           WHERE x.product_id = pr.p1 AND y.product_id = pr.p2) AS customer_count
  FROM (SELECT a.product_id AS p1, b.product_id AS p2
        FROM (SELECT DISTINCT product_id FROM ProductPurchases) a
        JOIN (SELECT DISTINCT product_id FROM ProductPurchases) b ON a.product_id < b.product_id) pr
) q
LEFT JOIN ProductInfo c1 ON c1.product_id = q.product1_id
LEFT JOIN ProductInfo c2 ON c2.product_id = q.product2_id
WHERE q.customer_count >= 3
ORDER BY q.customer_count DESC, q.product1_id, q.product2_id;
```

**Why it is correct:** it follows the spec literally: for every pair of products that exist, count the customers who bought both. A pair with no common customer gets a count of 0 and is filtered out. Pairs are generated with `<`, so each appears once.

**Cost model (reasoned):** with `P` distinct purchased products there are `P(P−1)/2` candidate pairs and each runs a subquery that finds the buyers of `p1` and probes for `p2`. Most candidate pairs have no common customer at all, and the work is spent finding that out. The cost scales with `P²` and is independent of how many pairs really occur. Index `(product_id, user_id)` makes each probe a seek instead of a scan.

### Approach 2: prune rare products, then self-join (`solutions/02_prune_then_self_join.sql`)

```sql
WITH popular AS (SELECT product_id FROM ProductPurchases GROUP BY product_id HAVING COUNT(*) >= 3),
basket AS (SELECT pp.user_id, pp.product_id FROM ProductPurchases pp JOIN popular p ON p.product_id = pp.product_id),
pairs AS (
  SELECT a.product_id AS product1_id, b.product_id AS product2_id, COUNT(*) AS customer_count
  FROM basket a JOIN basket b ON b.user_id = a.user_id AND b.product_id > a.product_id
  GROUP BY a.product_id, b.product_id HAVING COUNT(*) >= 3)
SELECT p.product1_id, p.product2_id, c1.category AS product1_category, c2.category AS product2_category, p.customer_count
FROM pairs p
LEFT JOIN ProductInfo c1 ON c1.product_id = p.product1_id
LEFT JOIN ProductInfo c2 ON c2.product_id = p.product2_id
ORDER BY p.customer_count DESC, p.product1_id, p.product2_id;
```

**Why it is correct:** removing products with fewer than 3 customers cannot remove a qualifying pair, since such a pair would need both of its products to have at least 3 customers. So the surviving pairs and counts are identical to approach 3's. (This is the *a priori* principle from frequent-itemset mining: a set can only be frequent if all its subsets are.) `COUNT(*)` replaces `COUNT(DISTINCT user_id)` because `(user_id, product_id)` is unique.

**Cost model (reasoned):** the saving is in the self-join: rows of rare products no longer generate pair rows. The cost is an extra aggregation pass to find the popular products, plus the filtered `basket`, which is materialised as a temporary table. The self-join then reads that table instead of the base table, so it **loses the primary-key range access** to a customer's products that approach 3 enjoys, and falls back to a hash join over a derived table. Whether the rows saved outweigh those costs depends on how heavy the long tail is; in a column store or a distributed engine, where the join's shuffle volume dominates, the balance can be different. This is the optimisation that looks obviously right and has to be measured (the bench table decides; it is the reason this approach is 02 and not 03).

### Approach 3 (optimal): self-join, group, then lookup (`solutions/03_self_join_group_by.sql`)

The SQL is the assembled query in section 4.

**Why it is correct:** the join produces exactly one row per customer per unordered pair they both bought. Grouping by the pair and counting distinct customers gives the pair's audience. `HAVING` applies the threshold on the aggregate. Categories are looked up after the threshold, so the join to `ProductInfo` cannot multiply rows (it is 1:1 on `product_id`), and it runs only on survivors.

**Cost model (reasoned):** the work is the size of the self-join, `Σ over customers of k(k−1)/2`, dominated by customers with big baskets because it is quadratic in `k`. The primary key `(user_id, product_id)` makes each customer's products adjacent, so for each row of `a` the matching rows of `b` (`product_id > a.product_id`) are one index range scan, with no hash table and no materialisation. Every joined row then goes into an aggregation keyed on the two ids. The volume of rows is the problem, not the lookup.

**Measured** (`gen.py` data, generated by the bench workflow; the table is filled in automatically, so never type numbers here):

<!-- BENCH:12-find-product-recommendation-pairs -->
<!-- /BENCH -->

### Why the optimal one wins

The expensive part of any solution here is the self-join's output, and approach 3 produces it with the fewest moving parts: it runs straight over the base table's primary key, with no temporary table before the aggregation and no extra pass. Approach 1 pays for every possible pair rather than every shared pair. Approach 2 has a sound idea, fewer join rows, but buys it with an extra pass and a materialised intermediate; when its saving is smaller than that bill it loses, which is why it pays to measure before calling an optimisation an improvement. The comparison can come out the other way on a different engine or a heavier tail (section 6c).

## 6. At scale

**(a) What breaks first.** *Reasoned, then checked by the bench table:* approach 1 breaks first, since `P²` grows with the catalogue even when few pairs co-occur. Approaches 2 and 3 are then limited by the same thing: the exploded join is quadratic in basket size, so a few customers with very large baskets can dominate it.

**(b) One machine, ~1M–100M rows.**
- The primary key `(user_id, product_id)` is exactly the index the self-join wants. `indexes.sql` adds `(product_id, user_id)` for the other direction: "customers per product" (approach 2's prune) and approach 1's probes are then answered from the index alone.
- The temporary table of the `GROUP BY` is keyed on two ids and holds one row per distinct pair seen so far. If the number of distinct pairs outgrows memory it spills to disk, and the aggregation becomes the bottleneck. A higher minimum count (for example a threshold of 10 instead of 3) shrinks the number of surviving pairs, but the temporary table is filled before the threshold is applied, so only reducing the join's input (approach 2's prune, a basket-size cap) reduces it.
- **Cap the basket size** for exploratory runs: a customer with 2,000 products produces about two million pair rows by themselves. A bot or a wholesale account is rarely a "recommendation" signal anyway. This changes the answer, so it is a business decision (follow-up 4).
- Do not add `DISTINCT` to `basket` "for safety" while the primary key guarantees uniqueness: it forces a sort or hash for nothing.

**(c) Distributed engines, billions of rows. *Reasoned, not measured.***
- *Shuffle:* the self-join shuffles `ProductPurchases` by `user_id` (both sides), which is balanced if customers have similar basket sizes. The pair rows are then re-shuffled by `(product1, product2)` for the count. Doing the pair counting with a **partial aggregate per task first** (count pairs within the task, then merge) cuts the second shuffle sharply for popular pairs.
- *Skew:* two kinds. Customer skew (one huge basket) produces a huge amount of pair rows from one key; cap or sample the basket. Pair skew (a handful of very popular pairs) is handled by partial aggregation.
- *Pruning by popularity* may be worth more here than on one machine (*reasoned, untested*): removing the long tail before the shuffle reduces the data that moves, not just the join output, and the primary-key range access that approach 3 enjoys in MySQL does not exist. Test it on your engine.
- *`COUNT(DISTINCT)`* per pair does not pre-aggregate well (partials must carry sets of customers). If the table is unique per (customer, product), use `COUNT(*)`; otherwise dedupe `(user_id, product_id)` once up front and then count.
- *Approximate answers:* for recommendations, an approximate distinct count (HyperLogLog) per pair, or counting pairs in a sample of customers, is usually acceptable, and a sketch error of a percent or two does not change a "top pairs" list much. It is **not** acceptable for a threshold at exactly 3, where one customer decides inclusion. Use it for ranking, not for the boundary.

**(d) The data-engineering answer.** Maintain the pair counts instead of recomputing them. A new purchase pairs with everything the customer already bought, and with the other new purchases in the same batch:

```sql
-- pair_counts(product1_id, product2_id, customer_count, PRIMARY KEY (product1_id, product2_id))
-- Snowflake / ANSI MERGE (UNVERIFIED). existing_purchases = rows already applied, new_batch = rows being applied now.
MERGE INTO pair_counts t
USING (
  SELECT product1_id, product2_id, SUM(c) AS c
  FROM (
    SELECT LEAST(n.product_id, o.product_id) AS product1_id, GREATEST(n.product_id, o.product_id) AS product2_id, COUNT(*) AS c
    FROM new_batch n JOIN existing_purchases o ON o.user_id = n.user_id AND o.product_id <> n.product_id
    GROUP BY 1, 2
    UNION ALL
    SELECT a.product_id, b.product_id, COUNT(*)
    FROM new_batch a JOIN new_batch b ON b.user_id = a.user_id AND b.product_id > a.product_id
    GROUP BY 1, 2
  ) d GROUP BY product1_id, product2_id
) s ON t.product1_id = s.product1_id AND t.product2_id = s.product2_id
WHEN MATCHED THEN UPDATE SET customer_count = t.customer_count + s.c
WHEN NOT MATCHED THEN INSERT (product1_id, product2_id, customer_count) VALUES (s.product1_id, s.product2_id, s.c);
-- Read side: SELECT ... FROM pair_counts WHERE customer_count >= 3, joined to ProductInfo twice, as in section 4.
```

Caveats interviewers probe. *Idempotency*: re-applying a batch double-counts, so track applied batches. *Duplicates*: a repeated (customer, product) must not create new pairs, so dedupe against `existing_purchases` first. *Deletes and refunds*: retraction needs the same join with a negative sign. The two halves of the union avoid counting a pair twice when both of its products arrive in the same batch.

## 7. Edge cases

Each "breaks" claim below is checked by execution: `mistakes/*.sql` are the tempting wrong queries, and the harness asserts that each one fails every dataset it names (`harness/test_mistakes.py`).

| Case | Dataset | Wrong queries it catches (`mistakes/`) |
|---|---|---|
| Mirrored pairs `(2,1)` next to `(1,2)` | `tests/edge_typical.sql`, `tests/edge_threshold.sql`, `tests/edge_ordering.sql` | `not_equal_join` |
| Self-join without the same-customer condition | `tests/edge_typical.sql`, `tests/edge_no_pairs.sql` | `join_without_same_customer` |
| Pair with exactly 3 customers; pair with exactly 2 | `tests/edge_threshold.sql`, `tests/edge_typical.sql` | `threshold_greater_than_3` |
| Quantity 0 on a purchase | `tests/edge_typical.sql` | `quantity_filter`, `count_rows_not_customers` |
| Product without a `ProductInfo` row | `tests/edge_unknown_product.sql` | `inner_join_categories` |
| Two products in the same category | `tests/edge_threshold.sql` | none of these mistakes |
| Every customer bought one product | `tests/edge_no_pairs.sql` | `join_without_same_customer` |
| Several qualifying pairs with ties on count and non-consecutive ids | `tests/edge_ordering.sql` | `ids_first_ordering`, `second_id_before_first` |
| No purchases | `tests/edge_empty.sql` | none |

No approach in `solutions/` is broken by any of these.

## 8. Interviewer follow-ups

1. **"Now triples."** Add a third join `c.product_id > b.product_id`. The row explosion becomes `k³` per basket, so pruning matters a lot more: first find the frequent pairs (this query), then only extend those to triples (a priori again).
2. **"Show how likely B is, given A."** That is *confidence*: `pair_count / customers_who_bought_A`, which is directional. Count customers per product (approach 2's `popular` CTE has it, if you keep the count), and consider both directions, so the `<` condition changes to `<>`.
3. **"Rank by something better than raw counts."** Raw counts favour popular products. *Lift* divides by the product of the individual popularities: `pair_count × total_customers / (count_A × count_B)`. You need the total number of customers as a third scalar.
4. **"One customer bought 5,000 products and is skewing the results."** Exclude or sample baskets over a size threshold *before* the self-join (a `HAVING COUNT(*) <= N` per customer). Say that it changes the semantic of the metric and ask whether wholesale buyers should count.
5. **"What if `ProductPurchases` has duplicate rows for the same customer and product?"** Then `COUNT(*)` overcounts and the self-join multiplies duplicates (two copies × three copies = six pair rows). Dedupe first (`SELECT DISTINCT user_id, product_id`) or keep `COUNT(DISTINCT user_id)`. This is why approach 3 uses the distinct form: it is correct regardless of the key, and `COUNT(*)` in approach 2 is only right because of the key.
6. **"Why join categories at the end?"** The lookup is 1:1 and cannot change the counts, so doing it before the aggregate only widens every exploded row and adds two joins on the largest intermediate result.

## 9. Snowflake notes (UNVERIFIED)

`snowflake.sql` keeps the shape of approach 3.

- The SQL is the same. Joins are hash joins distributed across the warehouse. The popularity prune of approach 2 is not applied in `snowflake.sql` because it is untested there; if you try it, check the query profile for *rows produced* by the self-join before and after.
- A different route to pairs: aggregate each customer's products with `ARRAY_AGG`, then expand the array pairs with a lateral flatten. It avoids a hash self-join but builds an array per customer, which is only attractive when baskets are small.
- For ranking-only use, `APPROX_COUNT_DISTINCT` (HyperLogLog) per pair is available. Not for the exact "≥ 3" boundary.
- There are no indexes (`indexes.sql` has no equivalent). Clustering `ProductPurchases` by `user_id` helps pruning for per-customer lookups, not the join itself.
- `LEAST`/`GREATEST` exist in both engines. Unquoted identifiers are returned upper-cased (`PRODUCT1_ID`).

## 10. Pattern links

Same pattern (self-join to form pairs, count co-occurrence):
- `13-find-category-recommendation-pairs`: the same shape, but the pair is of categories, and then the customer-per-pair count needs a deduplication step.
- `27-most-common-course-pairs`: another pairs-counted-across-people problem (courses instead of products).

Related:
- `14-customers-who-bought-all-products`: the other way to ask a question about "which products a customer bought" (all of a set, rather than pairs).
