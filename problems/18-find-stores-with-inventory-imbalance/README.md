# 18 · Find Stores with Inventory Imbalance

## 1. Problem & trigger phrases

Original: [Find Stores with Inventory Imbalance](https://leetcode.com/problems/find-stores-with-inventory-imbalance/) (LeetCode 3626, medium). Read the statement there; this guide only restates the spec in its own words.

**Spec (own words):** consider only stores that stock at least three products. In each, find the highest-priced product and the lowest-priced product. Keep the store if the highest-priced product has strictly fewer units in stock than the lowest-priced one. For each kept store, return its id, name, location, the two product names, and the ratio *units of the cheapest product ÷ units of the most expensive product*, rounded to 2 decimals. Order by that ratio descending, then store name ascending.

| Trigger phrase | What it forces in SQL |
|---|---|
| "most expensive product … cheapest product" | **Two rankings of the same rows**, one per direction (`price DESC`, `price ASC`), keeping rank 1 of each, then bringing the two rows together into one output row per store. Either self-join the two rank-1 sets or fold them with conditional aggregation. A `MAX(price)`/`MIN(price)` join-back finds the prices but multiplies rows on a tie. |
| "at least 3 different products" | A per-store count `>= 3`: `COUNT(*) OVER (PARTITION BY store_id)` or a `GROUP BY store_id HAVING COUNT(*) >= 3`. "Different products" means rows here (one row per product per store), not distinct prices. |
| "quantity is less than" | A comparison *between two rows of the same store*, so it can only be applied after both rows sit side by side. Strict `<`: equal quantities are excluded. |
| "imbalance ratio" | `cheapest_qty / most_expensive_qty`, in that order, `ROUND(…, 2)`. MySQL `/` returns a DECIMAL (`DIV` would truncate to an integer). |

## 2. Schema & grain

| Table | One row means | Keys that matter here |
|---|---|---|
| `inventory` | one product stocked at one store | `store_id`, `product_name`, `price`, `quantity` |
| `stores` | one store | `store_id` (PK), `store_name`, `location` (carried to the output) |

**Output grain:** one row per qualifying store. The input grain is one row per (store, product), so the grain changes **from many rows per store to one**, and the output row is built from *two* different input rows (the most expensive and the cheapest).

**Where the grain changes:**
1. Per store, ranking each product twice (no grain change yet: a window adds columns).
2. Selecting rank 1 in each direction leaves at most two rows per store (one when the same row is both ends).
3. Folding the (up to) two rows into one: either a join on `store_id` or `MAX(CASE …)` with `GROUP BY store_id`. This is the collapse to store grain, and the step where a tie that is not fully resolved turns into duplicate output rows.

## Assumptions

Confidence is `medium`: the statement does not say what happens when prices tie, so these are interpretations, each tested explicitly.

- **Price ties follow the reference tie-break: higher quantity wins, at both ends.** The highest-priced product with the most units is "the most expensive"; among the lowest-priced, the one with the most units is "the cheapest". Tested by `tests/edge_price_ties.sql`: Tie1 only comes out right if the 5-unit product, not the 2-unit one, is chosen as most expensive; Tie2 must choose the 9-unit product as cheapest.
- **If price and quantity both tie, the smaller `product_name` wins** (our assumption; the reference is silent). It is only there to make the answer deterministic, and is tested by `tests/edge_full_tie_assumption.sql`. Do not rely on it as part of the original problem.
- **When every product in a store has the same price,** the same row is both the most expensive and the cheapest, so the quantities are equal and the strict `<` excludes the store (`tests/edge_price_ties.sql`, store Flat).
- **"Different products" = inventory rows.** `schema.sql` declares `UNIQUE (store_id, product_name)`, so rows and distinct products are the same thing.
- **`quantity > 0`** (a `CHECK` in the schema). A zero quantity for the most expensive product would make the ratio a division by zero (NULL in MySQL), which the spec does not define.
- **Rounding:** `ROUND(x / y, 2)` on MySQL's exact DECIMAL result; halves round away from zero (13/8 = 1.6250 → 1.63). The ordering key is the *rounded* output column, so two stores that round to the same value are ordered by `store_name` (`tests/edge_ordering.sql`).

## 3. Hint ladder

<details><summary>Hint 1</summary>

Pattern: **top-1 and bottom-1 per group in the same query** (a ranking per group, run in both directions), followed by a comparison of the two picked rows.

</details>

<details><summary>Hint 2</summary>

Shape: (1) per store, count the products and rank them by price high-to-low and again low-to-high. (2) Keep the stores with 3 or more products, and from each only the rank-1 row of each direction. (3) Put those two rows side by side, one output row per store. (4) Compare the two quantities, compute the ratio, order the result.

</details>

<details><summary>Hint 3</summary>

Key trick: put the tie-break *inside* both `ORDER BY`s (`price …, quantity DESC, product_name ASC`) so each direction has exactly one rank-1 row; then fold the rows with `MAX(CASE WHEN rn_hi = 1 THEN … END)` and `MAX(CASE WHEN rn_lo = 1 THEN … END)` grouped by store. This needs no self-join, and it also handles the case where one row is rank 1 in both directions.

</details>

## 4. Decomposition

"Most expensive … cheapest" are two *separate* top-1 picks inside the same store; "strictly less" compares them. So: pick, pick, combine, compare.

1. **`ranked`: for each inventory row, store size and the rank in each direction.**
   *Why window functions here:* we need group-level facts (how many products the store has, where this row stands by price) while still keeping every row, since step 2 selects rows. `COUNT(*) OVER (PARTITION BY store_id)` gives the size; two `ROW_NUMBER()`s with opposite price order give the two rankings. *Why ROW_NUMBER, not RANK:* the tie-break (quantity, then name) makes each order total, so exactly one row per store has rank 1 in each direction.
2. **`ends`: keep `n_products >= 3` and rank-1 rows, fold to one row per store.**
   *Why a filter and a GROUP BY here:* the filter implements "at least 3 products" and throws away every row that is not an end point. After it, a store has at most two rows (one if the same row is both ends). `GROUP BY store_id` with `MAX(CASE …)` turns "up to two rows" into one row holding both products and both quantities; each `CASE` fires on exactly one row, so `MAX` simply picks it.
3. **Join `stores`, filter `hi_qty < lo_qty`, compute the ratio, order.**
   *Why a JOIN here:* name and location are attributes of the store, needed only on the final, already small, set. *Why this filter here:* it compares two rows' values, which only exist side by side after step 2.

```sql
WITH ranked AS (                                          -- step 1: facts per row, grain unchanged
  SELECT store_id, product_name, quantity,
         COUNT(*)     OVER (PARTITION BY store_id) AS n_products,
         ROW_NUMBER() OVER (PARTITION BY store_id ORDER BY price DESC, quantity DESC, product_name ASC) AS rn_hi,
         ROW_NUMBER() OVER (PARTITION BY store_id ORDER BY price ASC,  quantity DESC, product_name ASC) AS rn_lo
  FROM inventory
), ends AS (                                              -- step 2: <= 2 rows per store -> 1 row per store
  SELECT store_id,
         MAX(CASE WHEN rn_hi = 1 THEN product_name END) AS most_exp_product,
         MAX(CASE WHEN rn_hi = 1 THEN quantity     END) AS hi_qty,
         MAX(CASE WHEN rn_lo = 1 THEN product_name END) AS cheapest_product,
         MAX(CASE WHEN rn_lo = 1 THEN quantity     END) AS lo_qty
  FROM ranked
  WHERE n_products >= 3 AND (rn_hi = 1 OR rn_lo = 1)
  GROUP BY store_id
)
SELECT s.store_id, s.store_name, s.location, e.most_exp_product, e.cheapest_product,
       ROUND(e.lo_qty / e.hi_qty, 2) AS imbalance_ratio   -- step 3
FROM ends e
JOIN stores s ON s.store_id = e.store_id
WHERE e.hi_qty < e.lo_qty
ORDER BY imbalance_ratio DESC, s.store_name ASC;
```

Self-check before you submit: (a) every output store appears once; (b) for one output store, list its products by hand and confirm the two products you returned are really the price extremes; (c) check a store whose top price is shared by two products.

## 5. Approaches: brute force → optimal

### Approach 1: two "nobody beats me" anti-joins (`solutions/01_not_exists_two_ends.sql`)

```sql
SELECT s.store_id, s.store_name, s.location, hi.product_name, lo.product_name, ROUND(lo.quantity / hi.quantity, 2) AS imbalance_ratio
FROM stores s
JOIN inventory hi ON hi.store_id = s.store_id
 AND NOT EXISTS (SELECT 1 FROM inventory x WHERE x.store_id = hi.store_id
                  AND ( x.price > hi.price
                     OR (x.price = hi.price AND x.quantity > hi.quantity)
                     OR (x.price = hi.price AND x.quantity = hi.quantity AND x.product_name < hi.product_name) ))
JOIN inventory lo ON lo.store_id = s.store_id
 AND NOT EXISTS (… the mirror image with y.price < lo.price …)
WHERE (SELECT COUNT(*) FROM inventory c WHERE c.store_id = s.store_id) >= 3
  AND hi.quantity < lo.quantity
ORDER BY imbalance_ratio DESC, s.store_name;
```

**Why it is correct:** a row is the most expensive if no other row of its store beats it under (price, quantity, name); the order is total, so exactly one row qualifies per store. The same for the cheapest. Joining both on `store_id` gives one row per store. This is a natural first attempt: it translates the words "no product is more expensive" literally.

**Cost model (reasoned):** every inventory row runs two NOT EXISTS probes (as `hi` and as `lo` candidates), and every store also runs a correlated count. A probe reads one store's rows. Because `schema.sql` declares `UNIQUE (store_id, product_name)`, MySQL can find a store's rows through that index; without any index on `store_id`, each probe scans the whole table, which is quadratic. The cost is therefore (rows × average store size) with the index and (rows²) without. The unique key is already part of the schema; `indexes.sql` adds a covering version.

### Approach 2: two rankings in separate CTEs, self-join (`solutions/02_two_rankings_joined.sql`)

```sql
WITH top_priced AS (SELECT store_id, product_name, quantity,
                           COUNT(*) OVER (PARTITION BY store_id) AS n_products,
                           ROW_NUMBER() OVER (PARTITION BY store_id ORDER BY price DESC, quantity DESC, product_name) AS rn
                    FROM inventory),
     low_priced AS (SELECT store_id, product_name, quantity,
                           ROW_NUMBER() OVER (PARTITION BY store_id ORDER BY price ASC, quantity DESC, product_name) AS rn
                    FROM inventory)
SELECT … FROM stores s JOIN top_priced hi ON … AND hi.rn = 1 JOIN low_priced lo ON … AND lo.rn = 1
WHERE hi.n_products >= 3 AND hi.quantity < lo.quantity ORDER BY imbalance_ratio DESC, s.store_name;
```

**Why it is correct:** each CTE has a total order, so `rn = 1` is a single row per store; joining on `store_id` pairs the highest and the lowest. If one product is both, it pairs with itself (equal quantities, excluded).

**Cost model (reasoned):** two full scans of `inventory`, each with its own sort for its window (partition by store, order by price direction), and then a join of two filtered sets. No per-row subquery, so no dependence on a probe index; cost is two sorts of the whole table plus a join on one row per store.

### Approach 3 (optimal): one scan, two rankings, conditional-aggregation fold (`solutions/03_one_scan_pivot.sql`)

The SQL is the assembled query in section 4.

**Why it is correct:** the same total orders as approach 2, but the end rows are folded with `MAX(CASE …)` instead of joined. `MAX` ignores NULLs, so each output column takes its value from the single row where its `CASE` fires, and a product that is rank 1 in both directions fills both pairs of columns.

**Cost model (reasoned):** one scan of `inventory` feeds both rankings (they still need separate sorts because their `ORDER BY`s differ, but the scan and the size count are shared). After the filter the data is at most two rows per store, so the fold is a small group-by and the join to `stores` is on one row per store. The saving over approach 2 is the second scan and the self-join, not the sorts.

**Measured** (`gen.py` data, generated by the bench workflow; the table is filled in automatically, so never type numbers here):

<!-- BENCH:18-find-stores-with-inventory-imbalance -->
<!-- /BENCH -->

### Why the optimal one wins

Approach 3 reads `inventory` once and discards everything except the two end rows per store before any join, so every later step works on a number of rows proportional to the number of stores, not of products (reasoned). It also has the fewest places where a tie can multiply rows: there is no join between two sets that could each hold several matching rows per store. If the bench shows approach 1 close to it with the covering index, the reason is that an index-backed probe is also cheap; approach 3 is still the one whose cost does not depend on that index existing.

## 6. At scale

**(a) What breaks first.** *Reasoned, then checked by the bench table:* approach 1, as soon as the probe index is missing or not covering: every row triggers two correlated probes plus a count. Approach 2's two full sorts come next. Approach 3 pays one scan and two sorts, which is the lower bound for this shape on one machine.

**(b) One machine, ~1M–100M rows.**
- `schema.sql` already has `UNIQUE (store_id, product_name)`. If a copy of the table lacks it, approach 1 is the first to degrade, and the `store_id` index is the single most valuable one.
- `indexes.sql` adds `inventory (store_id, price, quantity, product_name)`. It is *covering* (no base-table visits) and keeps each store's rows contiguous and ordered by price. The "highest first" ranking can then read the index backwards for the price part; the quantity/name tie-break directions differ from the index order, so the sort cannot always be skipped (reasoned; check `EXPLAIN` for "Using filesort").
- Do not index `price` alone: the store is the partition, and a global price index is of no use to a per-store question.

**(c) Distributed engines, billions of rows. *Reasoned, not measured.***
- *Shuffle:* both rankings partition by `store_id`, so one shuffle on `store_id` serves both windows, and the count. Approach 2 reads and shuffles the table twice (or relies on the engine to reuse the shuffle). Approach 3 states the intent in one scan. After step 2 the data is two rows per store.
- *Skew:* a very large store (a marketplace, a warehouse pseudo-store) would put its whole partition on one worker, and the two sorts of that partition are the slowest task. The decomposable alternative: a store's maximum price and minimum price are `MAX`/`MIN` and can be pre-aggregated per task; only the tie-break among the rows at those two prices needs the detail rows. So filter to rows at the store's max or min price first (a join back on the small aggregate), then rank only those.
- *Snowflake:* no secondary indexes; `QUALIFY` replaces the filtering CTE for a single ranking, but this problem needs two different rankings, so the shape is kept. `MAX_BY(product_name, …)` would be natural, but it cannot express a three-key tie-break without packing the keys into one value.
- *Things to avoid:* a global `ORDER BY` of the full result is cheap here (one row per store), but a global sort of `inventory` is not. Approximate functions are inappropriate: the result names exact products.

**(d) The data-engineering answer.** Inventory changes constantly, but a store's extremes only change when its price extremes change. Maintain `store_extremes(store_id, n_products, hi_product, hi_qty, lo_product, lo_qty)` and recompute only the stores touched by a batch:

```sql
-- Snowflake / ANSI MERGE (UNVERIFIED): recompute the stores that appear in the change feed.
MERGE INTO store_extremes t
USING (SELECT store_id,
              MAX(n_products) AS n_products,
              MAX(CASE WHEN rn_hi = 1 THEN product_name END) AS hi_product,
              MAX(CASE WHEN rn_hi = 1 THEN quantity     END) AS hi_qty,
              MAX(CASE WHEN rn_lo = 1 THEN product_name END) AS lo_product,
              MAX(CASE WHEN rn_lo = 1 THEN quantity     END) AS lo_qty
       FROM ( /* the `ranked` CTE from section 4, restricted to
                 WHERE store_id IN (SELECT store_id FROM inventory_changes) */ ) r
       WHERE rn_hi = 1 OR rn_lo = 1
       GROUP BY store_id) s
ON t.store_id = s.store_id
WHEN MATCHED THEN UPDATE SET n_products = s.n_products, hi_product = s.hi_product, hi_qty = s.hi_qty,
                              lo_product = s.lo_product, lo_qty = s.lo_qty
WHEN NOT MATCHED THEN INSERT VALUES (s.store_id, s.n_products, s.hi_product, s.hi_qty, s.lo_product, s.lo_qty);
-- MySQL: the same with INSERT … SELECT … ON DUPLICATE KEY UPDATE.
```

The report is then `store_extremes` filtered on `n_products >= 3 AND hi_qty < lo_qty`. Caveats: a store whose last product is deleted must be removed (not just updated); recomputing a *whole* store on each change is correct and cheap because a store has few products, whereas trying to patch the max/min incrementally breaks when the current extreme is deleted or repriced (`MAX` is not retractable).

## 7. Edge cases

Each "breaks" claim below is checked by execution: `mistakes/*.sql` are the tempting wrong queries, and the harness asserts that each one fails every dataset it names (`harness/test_mistakes.py`).

| Case | Dataset | Wrong queries it catches (`mistakes/`) |
|---|---|---|
| Qualifying store; wrong-direction store; equal quantities; 2-product store | `tests/edge_typical.sql` | `non_strict_comparison` (equal quantities), `no_min_products_filter` (2-product store), `inverted_ratio`, `integer_division` |
| Exactly 3 products qualifies; 2 and 1 do not; a store with no inventory | `tests/edge_min_products.sql` | `no_min_products_filter`, `inverted_ratio` |
| Tie for highest price (higher quantity must win); tie for lowest price; one price for all products | `tests/edge_price_ties.sql` | `price_tie_lowest_quantity`, `join_back_on_max_min_price` (duplicate rows), `count_distinct_prices` (3 products, 2 distinct prices), `non_strict_comparison` |
| Price **and** quantity tie (our `product_name` assumption) | `tests/edge_full_tie_assumption.sql` | `join_back_on_max_min_price`, `count_distinct_prices`, `integer_division` |
| Ratio rounding: 13/8 = 1.6250 → 1.63, 201/200 = 1.0050 → 1.01 | `tests/edge_rounding.sql` | `integer_division` |
| Output order: equal ratios by store name; rounded vs unrounded ratio as the sort key | `tests/edge_ordering.sql` | `order_by_unrounded_ratio`, `inverted_ratio` |
| Inventory empty | `tests/edge_empty.sql` | none; every approach returns no rows |

No approach in `solutions/` is broken by any of these.

## 8. Interviewer follow-ups

1. **"What if the statement had to handle ties differently, e.g. return every tied product?"** Then each end can have several rows and the output grain changes to (store, expensive product, cheap product) pairs. Use `RANK()` instead of `ROW_NUMBER()` and join the two rank-1 sets; the ratio is then per pair. Decide first how the strict comparison applies to pairs.
2. **"Why not `MAX(price)` and `MIN(price)` with a join back?"** It finds the right prices, but when two products share the price the join returns both, so a store appears twice. The join-back also hides the tie-break rule instead of stating it. That is `mistakes/join_back_on_max_min_price.sql`.
3. **"Do it without window functions."** Approach 1 (anti-joins), or a correlated subquery with `ORDER BY … LIMIT 1` per end. Say that both are valid and that the anti-join form is the one whose tie behaviour is explicit.
4. **"Also report the second-cheapest."** Raise the rank limit; the conditional-aggregation fold generalises to `rn_lo = 2` columns, while the self-join form needs another join per rank.
5. **"Why does the order of the division matter?"** It is the cheapest quantity over the most-expensive quantity. Because the filter requires the most-expensive quantity to be strictly smaller, the ratio is always above 1; a value below 1 means the division is the wrong way round.

## 9. Snowflake notes (UNVERIFIED)

`snowflake.sql` keeps the shape of approach 3. What changes, and why:

- `IFF(cond, x, NULL)` replaces `CASE` inside `MAX`; the same logic, shorter.
- `MAX_BY(product_name, price)` returns the name at the maximum price, which is tempting for "most expensive product". It cannot apply a three-key tie-break and picks an arbitrary row on a price tie, so it fails the spec unless the keys are packed into one sortable value. The window form keeps the rule explicit.
- `QUALIFY` is not used because it filters one window expression; here two rankings are combined, so a CTE is still needed.
- Integer division: in Snowflake `a / b` on integers returns a `NUMBER` with scale (at least 6 digits), unlike an integer division in some other engines, so `ROUND(lo_qty / hi_qty, 2)` is correct as written.
- No secondary indexes; clustering on `store_id` helps keep a store's rows in the same micro-partitions, so the window partition is cheaper to build.

## 10. Pattern links

Same pattern (rank per group, keep a specific row; tie-break matters):
- `16-department-highest-salary`: top-1 per group keeping ties; the simplest form of this problem's single ranking.
- `19-department-top-three-salaries`: top-N per group with `DENSE_RANK`.
- `17-seasonal-sales-analysis`: aggregate first, then top-1 per group with a multi-key tie-break.
- `20-product-sales-analysis-iii` and `22-find-students-who-improved`: first/last row per key, the same two-ended look at a group; 22 compares the first and last scores per student-subject just as this compares the highest- and lowest-priced product.
- `26-find-consistently-improving-employees`: comparison of ordered rows within a group.
