# 01 · Market Analysis I

## 1. Problem & trigger phrases

Original: [Market Analysis I](https://leetcode.com/problems/market-analysis-i/) (LeetCode 1158, medium). Read the statement there; this guide only restates the spec in its own words.

**Spec (own words):** one output row per user: their id, their join date, and how many orders they placed **as the buyer** with an order date in 2019. A user with no such orders still appears, with 0. Sellers and the `Items` table do not matter.

| Trigger phrase | What it forces in SQL |
|---|---|
| "for each user" | The output grain is `Users`. Drive the query from `Users` and keep every row: `Users LEFT JOIN …`. A user missing from the output is a wrong answer, not a filtered one. |
| "orders made as a buyer in 2019" | Two conditions on the **right** table (role = buyer, year = 2019). On a LEFT JOIN, right-table conditions go in `ON` or in a pre-filtered CTE. In `WHERE` they delete the unmatched users. |
| "number of orders" | A count that must be 0, not NULL, for unmatched users. Use `COUNT(o.order_id)` after the join, or `COALESCE(n, 0)` on a pre-aggregated count. `COUNT(*)` after a LEFT JOIN gives 1. |

Also notice what is **not** in the wording. `Items` and `favorite_brand` are distractors here (Market Analysis II needs them). Recognising an unused table is part of decomposing the problem.

## 2. Schema & grain

| Table | One row means | Keys that matter here |
|---|---|---|
| `Users` | one user | `user_id` (PK), `join_date` |
| `Orders` | one order | `buyer_id`, `order_date`. `seller_id` is a second role of the same user: ignore it. |
| `Items` | one item | not needed |

**Output grain:** one row per `Users` row. As a sanity check, the output row count must equal `SELECT COUNT(*) FROM Users`, whatever is in `Orders`.

**Where the grain changes:** `Orders` is at order grain, and the answer is at user grain. The query has to collapse orders to one row per buyer (a `GROUP BY buyer_id`) and attach that to users (a `LEFT JOIN`). Most wrong answers come from doing these in an order that changes which rows exist:

- **Join first, then group** (approach 2): the joined rows are at order grain. An unmatched user is one row with all `Orders` columns NULL. That row is why `COUNT(*)` gives 1 and why a `WHERE` on an `Orders` column deletes the user.
- **Group first, then join** (approach 3): the CTE is already at buyer grain, so the join is 1:1 and can neither duplicate nor drop users. The only fix-up needed is NULL → 0.

`Orders` has no foreign key to `Users`, so an order can reference a buyer who is not a user. Such buyers must not create output rows, because the grain is `Users`, not "anyone who bought".

## 3. Hint ladder

<details><summary>Hint 1</summary>

Pattern: **outer-join preservation with a filtered count**. Every row of one table must survive, and you count matching rows from another table under a condition.

</details>

<details><summary>Hint 2</summary>

Shape: (1) keep only the orders that matter: buyer role, 2019. (2) Count them per buyer. (3) Attach the counts to every user, turning "no count" into 0.

</details>

<details><summary>Hint 3</summary>

Key trick: the 2019 condition must be applied where it cannot remove users. That means inside the CTE that pre-aggregates `Orders`, or in the `ON` clause of the LEFT JOIN, never in `WHERE`. Then count something that is NULL for unmatched users (`COUNT(o.order_id)`), or `COALESCE` the pre-aggregated count to 0. Write the year as a half-open range, `order_date >= '2019-01-01' AND order_date < '2020-01-01'`, so an index can use it.

</details>

## 4. Decomposition

Read the wording right to left. The noun phrase at the end ("number of orders … as a buyer in 2019") is something you compute. The phrase at the start ("for each user") is the frame you hang it on.

1. **`orders_2019`: filter `Orders` to the rows that count.**
   *Why a filter here:* "as a buyer in 2019" restricts only the right-hand table. If you apply it before any join, it is impossible for it to remove a user. Buyer role means the join key will be `buyer_id`; `seller_id` is never touched.
2. **`buyer_2019`: `GROUP BY buyer_id`, `COUNT(*)`.**
   *Why a GROUP BY here:* "number of orders" per user means going from order grain down to buyer grain. Doing it before the join keeps the join 1:1. `COUNT(*)` is safe at this point because every row in this CTE is a real order.
3. **Final: `Users LEFT JOIN buyer_2019`, `COALESCE(n, 0)`.**
   *Why a LEFT JOIN here:* "for each user" means every `Users` row survives. Users with no 2019 buys have no partner row. *Why COALESCE:* the count for those users must be 0, and a LEFT JOIN gives NULL.

Steps 1 and 2 merge into one CTE, because a filter and a group-by on the same table belong in a single `SELECT`:

```sql
WITH buyer_2019 AS (                          -- steps 1 + 2: order grain -> buyer grain
  SELECT buyer_id, COUNT(*) AS n_orders
  FROM Orders
  WHERE order_date >= '2019-01-01'
    AND order_date <  '2020-01-01'
  GROUP BY buyer_id
)
SELECT u.user_id                AS buyer_id,  -- step 3: back to user grain, all users kept
       u.join_date,
       COALESCE(b.n_orders, 0)  AS orders_in_2019
FROM Users u
LEFT JOIN buyer_2019 b ON b.buyer_id = u.user_id;
```

Self-check before you submit: count the output rows against `Users`. Then find one user you know has zero 2019 buys and confirm they show 0.

## 5. Approaches: brute force → optimal

### Approach 1: correlated subquery per user (`solutions/01_correlated_subquery.sql`)

```sql
SELECT u.user_id AS buyer_id, u.join_date,
       (SELECT COUNT(*) FROM Orders o
         WHERE o.buyer_id = u.user_id AND YEAR(o.order_date) = 2019) AS orders_in_2019
FROM Users u;
```

**Why it is correct:** the outer query is `Users` with no join and no filter, so every user appears exactly once. A scalar `COUNT(*)` over zero rows is 0, so the zero case needs no special handling. This is the most natural first attempt because it reads like the spec.

**Cost model (reasoned):** MySQL runs the subquery once per user; EXPLAIN shows it as a *dependent* subquery with `loops` = number of users. Without an index on `Orders.buyer_id`, each run scans all of `Orders`, so the cost is users × orders and grows quadratically. `YEAR(order_date)` wraps the column, so even an index on `order_date` cannot range-scan it. With `indexes.sql` (`buyer_id, order_date`), each run becomes an index range read of one buyer's entries, and the total cost becomes roughly linear. The approach is only slow because of the missing index; a correlated subquery is not slow in itself.

### Approach 2: LEFT JOIN, then GROUP BY (`solutions/02_left_join_group_by.sql`)

```sql
SELECT u.user_id AS buyer_id, u.join_date, COUNT(o.order_id) AS orders_in_2019
FROM Users u
LEFT JOIN Orders o
  ON  o.buyer_id = u.user_id
  AND o.order_date >= '2019-01-01' AND o.order_date < '2020-01-01'
GROUP BY u.user_id, u.join_date;
```

**Why it is correct:** both `Orders` conditions sit in `ON`, so they decide which orders match and never remove a user. `COUNT(o.order_id)` skips the NULL row an unmatched user gets, so it gives 0.

**Cost model (reasoned):** one pass over each table. Without an index, MySQL 8.0 runs a *left hash join*: it builds a hash table on one side and probes it with the other. The join output is order grain (every matched 2019 order plus one row per unmatched user). That whole intermediate result then goes through an *aggregate using temporary table*. So the expensive group-by works on the wide joined rows. Once the temporary table outgrows `tmp_table_size`, it spills to disk.

### Approach 3 (optimal): aggregate, then LEFT JOIN (`solutions/03_aggregate_then_join.sql`)

The SQL is the assembled query in section 4.

**Why it is correct:** the CTE has exactly one row per buyer with at least one 2019 order. The LEFT JOIN against it is 1:1 from the `Users` side, so it neither duplicates nor drops users. `COALESCE` turns "no row" into 0. A NULL `buyer_id` forms its own group in the CTE and never matches a user.

**Cost model (reasoned):** one scan of `Orders` (or of the index, if present) feeds a narrow aggregation keyed only by `buyer_id`. The result has at most one row per distinct buyer. MySQL materialises it and joins through an auto-generated key (`<auto_key0>` in EXPLAIN), so the join input is users + buyers, not users + 2019 orders. With `indexes.sql`, the scan follows `buyer_id` order, and the group-by can stream without a temporary table.

**Measured** (`gen.py` data, generated by the bench workflow; the table is filled in automatically, so never type numbers here):

<!-- BENCH:01-market-analysis-i -->
_Measured 2026-11-04 by the bench workflow: MySQL 8.0.46, AMD EPYC 9V74 80-Core Processor, 2 vCPU. Median of 3 runs after 1 warm-up; each statement capped at 60 s. Sizes are main-table rows from `gen.py`. Raw numbers and EXPLAIN ANALYZE: `bench/results/01-market-analysis-i.json`._

**Without indexes**

| Solution | 1,000 rows | 100,000 rows | 1,000,000 rows | × slower than optimal @ 1,000,000 |
|---|---:|---:|---:|---:|
| `01_correlated_subquery` | 36.3 ms | timeout >60s | timeout >60s † | > 31× |
| `02_left_join_group_by` | 2.43 ms | 182 ms | 2.22 s | 1.2× |
| `03_aggregate_then_join` (optimal) | 2.52 ms | 172 ms | 1.91 s | 1.0× |

† not run at this size: it already timed out at a smaller size.

**With `indexes.sql`**

| Solution | 1,000 rows | 100,000 rows | 1,000,000 rows | × slower than optimal @ 1,000,000 |
|---|---:|---:|---:|---:|
| `01_correlated_subquery` | 4.49 ms | 179 ms | 1.8 s | 1.1× |
| `02_left_join_group_by` | 5.42 ms | 196 ms | 2.3 s | 1.4× |
| `03_aggregate_then_join` (optimal) | 8.29 ms | 165 ms | 1.7 s | 1.0× |

> GitHub-hosted runners are shared, noisy VMs: compare the ratios between rows, not the absolute times.
<!-- /BENCH -->

### Why the optimal one wins

Approach 3 shrinks the big table to one row per buyer before it touches `Users`. That keeps the join 1:1, and the zero case becomes a `COALESCE` instead of depending on which column you `COUNT`. It also has the fewest ways to go wrong when someone edits it later. Its performance does not depend on a particular index existing, and the same aggregate-before-join shape is what keeps the shuffle small in distributed engines (section 6c). Approach 1 is the exception to know about: with the right composite index, MySQL turns it into a per-user index count that can match or beat approach 3 on one machine. Compare the "with indexes" table above with the "without" table. "Optimal" means optimal without assuming a particular physical design.

## 6. At scale

**(a) What breaks first.** *Reasoned, then checked by the bench table:* approach 1 without an index goes first, because users × orders grows quadratically. Approach 2's temporary-table group-by over order-grain rows comes next, once it no longer fits in memory. Approach 3 degrades last, because the group-by works on narrow rows and the join input is bounded by the number of distinct buyers.

**(b) One machine, ~1M–100M rows.**
- `indexes.sql` adds `Orders (buyer_id, order_date)`. It is *covering* for all three approaches, since no other `Orders` column is read. It turns approach 1 into an index nested loop, lets approach 2 probe the index instead of hashing, and lets approach 3 aggregate in index order. The bench runs every approach with and without it.
- There is a trade-off between index column orders. `(order_date, buyer_id)` range-scans only the 2019 slice but must sort or hash to group. `(buyer_id, order_date)` scans every buyer's entries but groups for free. If 2019 is a small part of a long history, the date-first index reads less (reasoned).
- Write the year as a half-open range, never `YEAR(col) = 2019` and never `BETWEEN '2019-01-01' AND '2019-12-31'`. The latter silently drops part of the last day if the column is ever widened to `DATETIME`.
- At 100M+ rows, `PARTITION BY RANGE (YEAR(order_date))` lets MySQL prune to the 2019 partition (reasoned). That requires the partitioning column in every unique key, which conflicts with `order_id` as the sole PK, a real migration cost.

**(c) Distributed engines, billions of rows. *Reasoned, not measured.***
- *Pruning:* in Snowflake, orders usually arrive roughly in date order, so micro-partitions are naturally clustered by `order_date`. A range predicate on the raw column lets the scan skip every partition outside 2019, often most of the table. If `Orders` arrives out of order, a clustering key on `order_date` restores this, at a reclustering credit cost.
- *Shuffle:* in Spark-style engines, `GROUP BY buyer_id` needs a shuffle by `buyer_id`. `COUNT` is decomposable, so each task pre-aggregates locally first and the shuffle carries at most one row per buyer per task. Approach 2 instead shuffles every 2019 order row to the join, then aggregates. Approach 3 shuffles partial counts. The final join with `Users` is a second shuffle on `user_id`, unless one side is small enough to broadcast.
- *Skew:* a handful of very heavy buyers would overload one reducer in a join-first plan. Pre-aggregation removes that skew for `COUNT`, because each heavy buyer leaves every task as a single partial-count row.
- *Things to avoid:* no `ORDER BY` is required ("any order"), so don't add one; a global sort over billions of rows is a single-stage bottleneck. If the follow-up becomes "distinct items bought", `COUNT(DISTINCT item_id)` can't be pre-aggregated to one number per task; partial results must carry the sets of values. For dashboards, `APPROX_COUNT_DISTINCT` (HyperLogLog, about 1–2% error) is acceptable. For billing or anything audited, it is not.

**(d) The data-engineering answer.** 2019 is a closed year. Unless back-dated corrections are possible, compute the counts once and store them. For a "this year so far" version, maintain a small aggregate incrementally instead of re-scanning `Orders`:

```sql
-- buyer_year_counts(buyer_id, yr, n_orders, PRIMARY KEY (buyer_id, yr)), fed by each new batch of orders.
-- Snowflake / ANSI MERGE (UNVERIFIED):
MERGE INTO buyer_year_counts t
USING (SELECT buyer_id, YEAR(order_date) AS yr, COUNT(*) AS n
       FROM orders_batch                       -- only rows not yet applied (by order_id watermark)
       WHERE buyer_id IS NOT NULL AND order_date IS NOT NULL
       GROUP BY buyer_id, YEAR(order_date)) s
ON t.buyer_id = s.buyer_id AND t.yr = s.yr
WHEN MATCHED THEN UPDATE SET n_orders = t.n_orders + s.n
WHEN NOT MATCHED THEN INSERT (buyer_id, yr, n_orders) VALUES (s.buyer_id, s.yr, s.n);

-- MySQL equivalent (no MERGE):
INSERT INTO buyer_year_counts (buyer_id, yr, n_orders)
SELECT buyer_id, YEAR(order_date), COUNT(*) FROM orders_batch
WHERE buyer_id IS NOT NULL AND order_date IS NOT NULL
GROUP BY buyer_id, YEAR(order_date)
ON DUPLICATE KEY UPDATE n_orders = n_orders + VALUES(n_orders);

-- The question then reads only users + the small aggregate:
SELECT u.user_id AS buyer_id, u.join_date, COALESCE(c.n_orders, 0) AS orders_in_2019
FROM Users u LEFT JOIN buyer_year_counts c ON c.buyer_id = u.user_id AND c.yr = 2019;
```

Caveats that interviewers probe. *Idempotency*: a batch applied twice double-counts, so track applied `order_id`s with a watermark and make re-runs no-ops. *Corrections*: an order whose buyer or date changes needs a −1 to the old (buyer, year) and a +1 to the new one. That means a change-data feed with before and after images, or recomputing only the affected keys. *Deletes* need the same retraction.

## 7. Edge cases

Each "breaks" claim below is checked by execution: `mistakes/*.sql` are the tempting wrong queries, and the harness asserts that each one fails every dataset it names (`harness/test_mistakes.py`).

| Case | Dataset | Wrong queries it catches (`mistakes/`) |
|---|---|---|
| User with buyer orders, none in 2019 (2018-12-31 and 2020-01-01) | `tests/edge_year_boundaries.sql` | `where_filter_on_right_table` (user vanishes), `count_star` (shows 1), `inner_join` |
| First and last day of 2019 | `tests/edge_year_boundaries.sql` | `off_by_one_range` |
| `Orders` completely empty | `tests/edge_no_orders.sql` | `inner_join`, `where_filter_on_right_table`, `count_star` |
| User who only sells in 2019; a self-purchase | `tests/edge_seller_only.sql` | `buyer_or_seller_join` (counts sales as purchases) |
| Two orders identical except `order_id`; buyer not in `Users`; seller-only user | `tests/edge_typical.sql` | `count_distinct_item` (merges the two orders), `drive_from_orders` (unknown buyer gets a row), `buyer_or_seller_join` |
| NULL `buyer_id` on a 2019 order; NULL `order_date`; NULL `join_date` | `tests/edge_nulls.sql` | `not_in_with_null_buyer`: `NOT IN` against a list containing NULL is never true, so zero-order users disappear. It passes every other dataset, which is what makes it a trap. |
| `Users` empty, `Orders` not | `tests/edge_empty_users.sql` | `drive_from_orders` (returns buyers that are not users) |

No approach in `solutions/` is broken by any of these. The brute force is slow without an index, not wrong.

## 8. Interviewer follow-ups

1. **"Also return each user's 2019 sales count."** Pre-aggregate the seller role in a second CTE and LEFT JOIN it too. Don't LEFT JOIN `Orders` twice in one `FROM` (once on `buyer_id`, once on `seller_id`) and then count. Each user's buy rows multiply with their sell rows (fan-out), so both counts come out inflated. Aggregating before joining is the cure.
2. **"Only users who joined before 2019."** That is a filter on the *left* table, so `WHERE u.join_date < '2019-01-01'` is correct here. It is the mirror image of the trap in section 1. Note that NULL `join_date` users are then excluded; say so.
3. **"Distinct items bought instead of orders."** Use `COUNT(DISTINCT item_id)` inside the CTE. Point out that it is not decomposable at scale (section 6c).
4. **"Every year, not just 2019, with zeros."** You now need a scaffold: `Users CROSS JOIN` a year list, then LEFT JOIN `(buyer_id, yr)` counts. The output grain becomes (user, year). Same pattern as `09-count-salary-categories` and `30-calculate-a-rolling-average-of-total-revenue`.
5. **"Why not `YEAR(order_date) = 2019`?"** It returns the same rows here, but it is not sargable: no index range scan, and weaker pruning in warehouses. It also stops working if the column becomes a timezone-aware timestamp and "2019" has to mean a business timezone.

## 9. Snowflake notes (UNVERIFIED)

`snowflake.sql` keeps the shape of approach 3. What changes, and why:

- `ZEROIFNULL(n)` (or `COALESCE`) is the same thing. `COUNT_IF(order_date >= … AND order_date < …)` allows a single-pass variant of approach 2 without a CASE.
- The win in Snowflake comes from **pruning, not from indexes**. There are no secondary indexes, so `indexes.sql` has no equivalent. A raw-column range predicate is the form known to prune. Whether `YEAR(order_date) = 2019` also prunes depends on the optimizer: check *Partitions scanned* vs *Partitions total* in the query profile.
- The CTE is not guaranteed to be materialised; the optimizer may inline it and choose its own join or aggregation order. Writing aggregate-then-join still matters, because it states the 1:1 intent and keeps the query correct if someone edits it later.
- Unquoted identifiers are upper-cased. The column `buyer_id` comes back as `BUYER_ID`, which matters if downstream code is case-sensitive.

## 10. Pattern links

Same pattern (outer-join preservation, filter placement, zero instead of NULL):
- `02-confirmation-rate`: LEFT JOIN preserve plus a ratio that must be 0 for users with no rows.
- `03-investments-in-2016`: existence / non-existence of "another row", using EXISTS or a window count.

Builds on it:
- `09-count-salary-categories`: when the zero rows don't exist in any table, you have to *generate* a scaffold to LEFT JOIN onto.
- `30-calculate-a-rolling-average-of-total-revenue`: the same scaffold idea with a real calendar.
- `04-monthly-transactions-i`, `07-trips-and-users`: conditional aggregation, the single-pass alternative to filtering before you count.
