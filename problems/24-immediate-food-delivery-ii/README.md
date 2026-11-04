# 24 · Immediate Food Delivery II

## 1. Problem & trigger phrases

Original: [Immediate Food Delivery II](https://leetcode.com/problems/immediate-food-delivery-ii/) (LeetCode 1174, medium). Read the statement there; this guide only restates the spec in its own words.

**Spec (own words):** an order is *immediate* if the customer's preferred delivery date equals the order date. Look only at each customer's **first** order (the one with the earliest order date; the table guarantees there is exactly one). Report the percentage of those first orders that are immediate, as a number from 0 to 100 rounded to 2 decimals.

| Trigger phrase | What it forces in SQL |
|---|---|
| "first order of a customer" | A per-customer anchor: `MIN(order_date)` per `customer_id` (then join back), a correlated `= (SELECT MIN …)`, or `ROW_NUMBER() … = 1`. It is the earliest **date**, not the smallest `delivery_id`. The set after this step has one row per customer, and that is the population for the percentage. |
| "percentage of immediate orders" | A conditional average over that population: `AVG(pref = order_date)` or `SUM(CASE …) / COUNT(*)`. The numerator and the denominator must both come from the first-order set. |
| "rounded to 2 decimal places" | `ROUND(100 * …, 2)`: scale to a percentage first, then round. Rounding the fraction and then multiplying (`ROUND(x, 2) * 100`) gives 43.00 for 3/7 instead of 42.86. |

## 2. Schema & grain

| Table | One row means | Keys that matter here |
|---|---|---|
| `Delivery` | one order | `delivery_id` (PK, says nothing about time), `customer_id`, `order_date`, `customer_pref_delivery_date` |

**Output grain:** one scalar row with one column.

**Where the grain changes:** three levels. Order grain → **first-order-per-customer grain** (the filter that defines the population) → **one number** (the average). The classic bug is to skip the first level and average over all orders, which weights customers by how often they order and lets non-first orders leak in.

`delivery_id` is a surrogate key: it need not increase with `order_date`. "First" is defined by the date.

## Assumptions

- **Empty `Delivery`.** The spec says this is not tested. `0 / 0` is undefined, and MySQL evaluates it (and `AVG` of nothing) to `NULL` in a `SELECT`. All three approaches return `NULL`; `tests/edge_empty.sql` records it. Do not rely on it as part of the original problem.
- **Scale and rounding.** The percentage is on a 0–100 scale. `ROUND(…, 2)` is applied to the exact decimal value, and halves round away from zero. `AVG` of 0/1 flags in MySQL has four decimal places, so `100 * AVG(…)` has two (3/7 → 0.4286 → 42.86, which equals the exact rounding of 42.857…).
- **Ties for the first order do not exist** (guaranteed). If they did, "first order" would need a tie-break and the percentage could count a customer twice under the join-back approaches. Later orders may share a date (`tests/edge_thirds.sql`), which is harmless.

## 3. Hint ladder

<details><summary>Hint 1</summary>

Pattern: **first row per key, then a ratio over those rows** (a cohort-style measure). Reduce to one row per customer, then average a 0/1 flag.

</details>

<details><summary>Hint 2</summary>

Shape: (1) pick each customer's first order (earliest date). (2) For those orders, compute the flag "preferred date equals order date". (3) Average the flag, multiply by 100, round to 2 decimals.

</details>

<details><summary>Hint 3</summary>

Key trick: do the percentage only on the first-order set, and make the flag a 0/1 value so the average is the share: `AVG(customer_pref_delivery_date = order_date)`. If you use `SUM(CASE WHEN … THEN 1 END)`, add `ELSE 0`, or the sum of nothing is NULL when no first order is immediate.

</details>

## 4. Decomposition

"Percentage of immediate orders among the first orders" = (first orders that are immediate) / (first orders). Both counts come from one set, so build that set first.

1. **`first_orders`: each customer's first order.**
   *Why a window function here:* we need to pick one row per customer out of several, by date, and keep that row's other columns. `ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY order_date)` numbers each customer's orders from the earliest; `rn = 1` is the first order. (Equivalent: `GROUP BY customer_id` for `MIN(order_date)` and a join back on both keys; correlated `= (SELECT MIN …)`.)
2. **Filter `rn = 1`.**
   *Why a filter here:* it defines the population. After it there is exactly one row per customer, so every average from here on is "per customer".
3. **Flag, average, scale, round.**
   *Why a conditional average here:* `customer_pref_delivery_date = order_date` is 1 for an immediate order and 0 otherwise; its average over the population is the share. Multiply by 100 for a percentage, then round once at the end.

```sql
WITH first_orders AS (                                           -- step 1
  SELECT order_date, customer_pref_delivery_date,
         ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY order_date) AS rn
  FROM Delivery
)
SELECT ROUND(100 * AVG(customer_pref_delivery_date = order_date), 2) AS immediate_percentage   -- step 3
FROM first_orders
WHERE rn = 1;                                                    -- step 2
```

Self-check before you submit: the row count after `rn = 1` equals `COUNT(DISTINCT customer_id)`. Pick a customer whose later order is immediate while the first is not, and confirm it does not count.

## 5. Approaches: brute force → optimal

### Approach 1: correlated `MIN` filter (`solutions/01_correlated_first_order.sql`)

```sql
SELECT ROUND(100 * SUM(d.customer_pref_delivery_date = d.order_date) / COUNT(*), 2) AS immediate_percentage
FROM Delivery d
WHERE d.order_date = (SELECT MIN(x.order_date) FROM Delivery x WHERE x.customer_id = d.customer_id);
```

**Why it is correct:** the `WHERE` keeps an order only when its date equals the earliest date of its customer, i.e. the first order. The guarantee that the first order is unique means exactly one row per customer survives. The numerator is the count of surviving rows with the flag set (`SUM` of a 0/1 expression), the denominator is the count of surviving rows.

**Cost model (reasoned):** one subquery per `Delivery` row. The primary key is `delivery_id`, so nothing helps a lookup by `customer_id`: each execution scans the table, which is quadratic in the number of orders. MySQL may rewrite the subquery, so check `EXPLAIN`. With `indexes.sql` (`customer_id, order_date, …`) each `MIN` is a single read at the start of a customer's range and the work becomes roughly linear.

### Approach 2: group, then join back (`solutions/02_join_to_first_date.sql`)

```sql
SELECT ROUND(100 * AVG(d.customer_pref_delivery_date = d.order_date), 2) AS immediate_percentage
FROM Delivery d
JOIN (SELECT customer_id, MIN(order_date) AS first_date FROM Delivery GROUP BY customer_id) f
  ON f.customer_id = d.customer_id AND f.first_date = d.order_date;
```

**Why it is correct:** the derived table has one row per customer with the first date; the join on `(customer_id, order_date)` returns the first order (unique, so the join cannot duplicate a customer). `AVG` of the 0/1 flag over that set is the share.

**Cost model (reasoned):** two reads of `Delivery`: an aggregation by `customer_id` (a hash or sorted group-by, one row per customer out) and a hash join of the whole table against the aggregate. Linear in rows, but the second pass joins every order just to discard most of them.

### Approach 3 (optimal): `ROW_NUMBER` in one pass (`solutions/03_row_number_first.sql`)

The SQL is the assembled query in section 4.

**Why it is correct:** within each customer, orders are ranked by date and `rn = 1` is the earliest; with a unique first date, exactly one row per customer. The average is over those rows.

**Cost model (reasoned):** one scan of `Delivery`, ordered by `(customer_id, order_date)` for the window: a sort without an index, or an index scan with `indexes.sql`. The filter and the final average work on the stream, with no join and no second read. Cost is O(n log n) for the sort in the worst case, O(n) with the covering index.

**Measured** (`gen.py` data, generated by the bench workflow; the table is filled in automatically, so never type numbers here):

<!-- BENCH:24-immediate-food-delivery-ii -->
<!-- /BENCH -->

### Why the optimal one wins

Approach 3 gets "first order per customer" without comparing every order to a precomputed minimum, and without a second pass: the ordering inside the window is the definition of "first". Approach 2 reads the table twice, and approach 1 repeats a lookup per row. The difference in the bench table is mostly the cost of the sort or the lookup, so the covering index in `indexes.sql` matters more here than the SQL shape: `delivery_id` as the primary key gives no help. Compare the "with indexes" and "without" tables.

## 6. At scale

**(a) What breaks first.** *Reasoned, then checked by the bench table:* approach 1 without an index (a scan of the table for every order). Approach 2 follows on memory: the hash join against the whole table. Approach 3 degrades last, at the memory limit of its sort.

**(b) One machine, ~1M–100M rows.**
- `indexes.sql` adds `Delivery (customer_id, order_date, customer_pref_delivery_date)`. It is covering and delivers rows ordered by customer and date, which is the window's partition and order, the group-by's key, and the correlated lookup's range. It removes the sort in approach 3 and the scan in approach 1.
- The primary key on `delivery_id` is the wrong physical order for this question, but changing the clustering key of a 100M-row table is expensive; a covering secondary index is the usual compromise.
- Compute the percentage on a *recent* slice when the question allows it: the first order of a customer never changes once written, so older customers need not be rescanned (section 6d).

**(c) Distributed engines, billions of rows. *Reasoned, not measured.***
- *Shuffle:* the window shuffles every order by `customer_id` and sorts within the partition. Approach 2's `MIN` is decomposable: each task keeps one candidate per customer, so the first shuffle is smaller; but the join back brings the whole table to the key again. A smaller plan: find each customer's first-order flag with an aggregate that carries the flag along with the date (`MIN_BY(flag, order_date)`, or `MIN` over a packed key), so that one shuffle of partial aggregates produces the answer without a join.
- *Skew:* a customer with millions of orders (a corporate account) overloads one task in the window plan; the partial-aggregate plan does not have that problem.
- *Snowflake:* `QUALIFY ROW_NUMBER() … = 1` in a CTE; no secondary indexes. Clustering by `customer_id` helps the partition. The final aggregate is over one row per customer.
- *Things to avoid:* a global sort, and `COUNT(DISTINCT customer_id)` over the whole table just to get a denominator when the first-order set already has one row per customer.

**(d) The data-engineering answer.** A customer's first order is written once. Keep `customer_first_order(customer_id, order_date, is_immediate)` and add customers as they appear; the percentage is then one aggregate over a table with one row per customer:

```sql
-- customer_first_order(customer_id PK, order_date DATE, is_immediate TINYINT)
-- Snowflake / ANSI MERGE (UNVERIFIED): fold a batch of new orders into the first-order table.
MERGE INTO customer_first_order t
USING (SELECT customer_id, order_date, IFF(customer_pref_delivery_date = order_date, 1, 0) AS is_immediate
       FROM orders_batch
       QUALIFY ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY order_date) = 1) s
ON t.customer_id = s.customer_id
WHEN MATCHED AND s.order_date < t.order_date THEN UPDATE SET order_date = s.order_date, is_immediate = s.is_immediate
WHEN NOT MATCHED THEN INSERT (customer_id, order_date, is_immediate) VALUES (s.customer_id, s.order_date, s.is_immediate);

-- MySQL equivalent: INSERT … SELECT … ON DUPLICATE KEY UPDATE with
--   is_immediate = IF(VALUES(order_date) < order_date, VALUES(is_immediate), is_immediate),
--   order_date   = IF(VALUES(order_date) < order_date, VALUES(order_date), order_date)
--   (MySQL evaluates the SET list left to right, so the date must be assigned LAST, after the column that depends on it.)

SELECT ROUND(100 * AVG(is_immediate), 2) AS immediate_percentage FROM customer_first_order;
```

Caveats interviewers probe: the update only handles **late-arriving earlier orders** (a back-dated order replaces the first); a deleted or corrected first order needs a recompute of that customer from the detail rows; and the batch must be idempotent (the `MERGE` above is, since re-applying the same first order changes nothing).

## 7. Edge cases

Each "breaks" claim below is checked by execution: `mistakes/*.sql` are the tempting wrong queries, and the harness asserts that each one fails every dataset it names (`harness/test_mistakes.py`).

| Case | Dataset | Wrong queries it catches (`mistakes/`) |
|---|---|---|
| First order scheduled but a later one immediate; smallest `delivery_id` is not the earliest order | `tests/edge_typical.sql` | `all_orders_not_first`, `first_by_delivery_id`, `any_immediate_order`, `fraction_not_percent` |
| 3 of 7: 42.857… → 42.86 | `tests/edge_rounding.sql` | `round_before_percent` (43.00), `fraction_not_percent` |
| 1 of 3: 33.33; a customer with later orders on a shared date | `tests/edge_thirds.sql` | `round_before_percent` (33.00), `all_orders_not_first`, `latest_order_instead_of_first`, `fraction_not_percent` |
| No first order is immediate: 0.00, not NULL; an immediate later order must not count | `tests/edge_none_immediate.sql` | `sum_case_without_else`, `all_orders_not_first`, `any_immediate_order`, `latest_order_instead_of_first` |
| Every first order is immediate: 100.00 | `tests/edge_all_immediate.sql` | `all_orders_not_first`, `latest_order_instead_of_first`, `fraction_not_percent` |
| `Delivery` empty (not tested by the spec) | `tests/edge_empty.sql` | none; all approaches return `NULL`, see Assumptions |

No approach in `solutions/` is broken by any of these.

## 8. Interviewer follow-ups

1. **"Immediate percentage per month of the customer's first order."** Add `DATE_FORMAT(order_date, '%Y-%m')` (or `DATE_FORMAT(…, '%Y-%m-01')`) to the select and `GROUP BY` on it. The population is still the first-order set, so the filter must come before the grouping, not after.
2. **"What if two orders tie for a customer's first date?"** Then "first" needs a tie-break (`ORDER BY order_date, delivery_id` in the window). The join-back approaches would count a customer twice, which is a reason to prefer the window for robustness.
3. **"Compare the immediate share of first orders with the immediate share of all later orders."** Compute both populations in one pass with the same `ROW_NUMBER` (`rn = 1` versus `rn > 1`) and conditional averages; no second query is needed.
4. **"Why does `ROUND(AVG(x), 2) * 100` give a different answer?"** Rounding happens at the wrong scale: it keeps two decimals of a fraction, i.e. whole percentage points only. Round at the end, once.
5. **"A customer ordered and cancelled; the first *successful* order is what counts."** Filter the cancelled rows out *before* ranking (a `WHERE` in the CTE), not after, otherwise the first (cancelled) order is picked and then removed, leaving the customer with no first order.

## 9. Snowflake notes (UNVERIFIED)

`snowflake.sql` is approach 3. What changes, and why:

- `QUALIFY ROW_NUMBER() OVER (...) = 1` removes the `rn` column and the outer `WHERE`. It must sit in its own CTE: an aggregate in the same `SELECT` is evaluated before the window function, so `QUALIFY` would see the aggregated result.
- `IFF(cond, 1, 0)` replaces MySQL's boolean-as-number trick (`AVG(a = b)`); the explicit 0/1 does not depend on boolean-to-number coercion.
- `AVG` of `NUMBER` has scale, and `ROUND(…, 2)` rounds half away from zero on exact numbers, as in MySQL. The percentage is therefore the same, but check the intermediate scale if the flags were `FLOAT`.
- No secondary indexes; cluster by `customer_id` to keep a customer's orders together. `MIN_BY(flag, order_date)` per customer is a one-pass alternative, as noted in section 6c.

## 10. Pattern links

Same pattern (first row per key, then a measure over those rows):
- `23-game-play-analysis-iv`: first login per player as the anchor, then a share of players retained (a fraction instead of a percentage; an extra row at `anchor + 1`).
- `20-product-sales-analysis-iii`: first year per product, keeping all rows of that year.
- `22-find-students-who-improved`: first and last row per group, compared.
- `21-product-price-at-a-given-date`: as-of row per key with a default.
- `02-confirmation-rate`: a conditional average per key (`AVG(flag)`) with a LEFT JOIN so keys without rows get 0.
- `36-find-churn-risk-customers`: latest versus earlier behaviour per customer.
