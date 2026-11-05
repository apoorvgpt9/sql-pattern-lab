# 45 · Median Order Amount per Store

## 1. Problem & trigger phrases

Original problem written for this repo (SPL-MED-01). There is no external statement: LeetCode's median problems (569, 571) are Premium, so this one fills the gap with its own spec and data.

**Spec:** for each store that has orders, report the median order amount, rounded to 2 decimals. Sort the store's n orders by amount, breaking ties by `order_id`. When n is odd, the median is the middle value; when n is even, it is the mean of the two middle values. Output `store_id, median_amount`, sorted by `store_id`.

| Trigger phrase | What it forces in SQL |
|---|---|
| "median order amount per store" | MySQL 8.0 has no `MEDIAN()` or `PERCENTILE_CONT`. A median is a **position** in sorted order, so you need each row's position within its store (`ROW_NUMBER() OVER (PARTITION BY store_id ORDER BY …)`) and the store's size (`COUNT(*) OVER (PARTITION BY store_id)`). Then keep the middle position(s). |
| "even number of orders" | Two middle rows, averaged. One filter covers both cases: `rn IN ((n + 1) DIV 2, n DIV 2 + 1)`. For odd n both expressions name the same row; for even n they name the two middle rows. `AVG` over the kept rows is then the median either way. |
| "duplicate amounts" | Positions must be **unique and gap-free** even when amounts tie. That means `ROW_NUMBER` with a tie-break column (`order_id`). `RANK` leaves gaps (1, 1, 1, 4), so the middle position may not exist. `DENSE_RANK` compresses (1, 1, 1, 2), so position 2 is no longer the middle. |

Two MySQL arithmetic details also decide correctness. `n / 2` is *decimal* division (`5 / 2 = 2.5000`), which never equals an integer row number. Use `DIV`. And `AVG` over `DECIMAL(10,2)` is exact, with scale 6, so `ROUND(…, 2)` rounds a midpoint like `10.125000` half away from zero, to `10.13`.

## 2. Schema & grain

| Table | One row means | Keys that matter here |
|---|---|---|
| `StoreOrders` | one order | `order_id` (PK, the tie-break), `store_id`, `amount` (`DECIMAL(10,2)`, never NULL) |

**Output grain:** one row per `store_id` that has at least one order. There is no stores table, so a store with no orders cannot appear.

**Where the grain changes:**
1. *Order grain, annotated:* the window functions add `rn` (position within the store) and `n` (store size) to every order **without** collapsing rows. Positions are a per-row fact that needs the whole partition: you cannot know you are row 3 of 5 without seeing the other four.
2. *Filter at order grain:* keep only the 1 or 2 middle rows per store.
3. *Store grain:* `GROUP BY store_id` + `AVG` collapses the 1–2 survivors into one median.

The common mistake is collapsing too early. `GROUP BY store_id` first gives you `n`, but it throws away the sorted rows you need to find the middle. That is why `n` comes from a window here, not from a `GROUP BY`. (Approach 1 gets it from a correlated count instead.)

## 3. Hint ladder

<details><summary>Hint 1</summary>

Pattern: **positional statistic with window functions**: number the rows inside each group and count the group, then pick rows by position.

</details>

<details><summary>Hint 2</summary>

Shape: (1) for every order, compute its position among its store's orders (by amount, then order_id) and the store's order count. (2) Keep the middle position, or the two middle positions. (3) Average what is left per store and round.

</details>

<details><summary>Hint 3</summary>

Key clause: `ROW_NUMBER() OVER w AS rn, COUNT(*) OVER (w ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS n … WINDOW w AS (PARTITION BY store_id ORDER BY amount, order_id)`, then `WHERE rn IN ((n + 1) DIV 2, n DIV 2 + 1)` and `ROUND(AVG(amount), 2)` per store. Use `DIV`, not `/`. Sharing one window ordering lets MySQL sort once.

</details>

## 4. Decomposition

"Median" names a value, but it is defined by a **position**: the middle of a sorted list. Turn the definition into two numbers per row (my position, my group's size) and one comparison (am I in the middle?).

1. **`ranked`: `ROW_NUMBER` + `COUNT(*)` over the store's window.**
   *Why a window and not a GROUP BY:* both numbers depend on the whole store, but every order must survive, because the middle rows are what we want. A window adds group-level facts to each row without collapsing. *Why `ROW_NUMBER` with `order_id`:* positions must be 1..n with no ties and no gaps, even for equal amounts (trigger "duplicate amounts"). *Why the explicit frame on `COUNT`:* with an `ORDER BY` in the window, the default frame stops at the current row, which gives a running count. `ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING` makes it the whole store. Sharing the ordering with `ROW_NUMBER` lets MySQL sort once (section 5).
2. **Filter: `rn IN ((n + 1) DIV 2, n DIV 2 + 1)`.**
   *Why a filter here:* the median uses only the middle row(s). For n = 5 the list is (3, 3), which is one row. For n = 4 it is (2, 3), which is two rows. Integer `DIV` keeps the positions integral.
3. **`GROUP BY store_id`, `ROUND(AVG(amount), 2)`.**
   *Why a GROUP BY here:* back to one row per store. `AVG` of one row is that row, and `AVG` of two rows is their mean, so the odd/even cases need no `CASE`.

```sql
WITH ranked AS (                                     -- step 1: position + store size on every order
  SELECT store_id, amount,
         ROW_NUMBER() OVER w AS rn,
         COUNT(*)     OVER (w ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS n
  FROM StoreOrders
  WINDOW w AS (PARTITION BY store_id ORDER BY amount, order_id)
)
SELECT store_id, ROUND(AVG(amount), 2) AS median_amount   -- step 3: 1 or 2 rows -> one value
FROM ranked
WHERE rn IN ((n + 1) DIV 2, n DIV 2 + 1)                  -- step 2: the middle (odd: same row twice)
GROUP BY store_id
ORDER BY store_id;
```

Self-check: for each store, the filter must keep exactly 1 row when n is odd and 2 when n is even. `SELECT store_id, n, COUNT(*) … GROUP BY store_id, n` on the filtered rows shows it at a glance.

## 5. Approaches: brute force → optimal

### Approach 1: self-join position counting (`solutions/01_self_join_positions.sql`)

```sql
WITH positioned AS (
  SELECT o.store_id, o.amount,
         1 + (SELECT COUNT(*) FROM StoreOrders x
              WHERE x.store_id = o.store_id
                AND (x.amount < o.amount OR (x.amount = o.amount AND x.order_id < o.order_id))) AS pos,
         (SELECT COUNT(*) FROM StoreOrders x WHERE x.store_id = o.store_id) AS n
  FROM StoreOrders o
)
SELECT store_id, ROUND(AVG(amount), 2) AS median_amount
FROM positioned
WHERE pos IN ((n + 1) DIV 2, n DIV 2 + 1)
GROUP BY store_id
ORDER BY store_id;
```

**Why it is correct:** a row's position is 1 + the number of rows in its store that come before it in (amount, order_id) order. That order is total (order_id is unique), so positions are exactly 1..n, the same numbers `ROW_NUMBER` produces. The rest is identical to the window version. This is the pre-window-function way to compute a median, and the natural first attempt if you think "how many orders are cheaper than this one?".

**Cost model (reasoned, plan shape checked with `EXPLAIN FORMAT=TREE`):** two dependent subqueries per order. Without an index each one scans the whole table, so the cost is orders² overall. With `indexes.sql` (`store_id, amount, order_id`), each becomes a covering range read of one store, so the cost is Σ over stores of n_s². That is still quadratic *within* a store, and `gen.py` deliberately has flagship stores with thousands of orders. Expect this approach to hit the bench's 60-second limit at the larger sizes, with the index or without.

### Approach 2: ROW_NUMBER ascending vs descending (`solutions/02_row_number_asc_desc.sql`)

```sql
WITH numbered AS (
  SELECT store_id, amount,
         ROW_NUMBER() OVER (PARTITION BY store_id ORDER BY amount ASC,  order_id ASC)  AS rn_asc,
         ROW_NUMBER() OVER (PARTITION BY store_id ORDER BY amount DESC, order_id DESC) AS rn_desc
  FROM StoreOrders
)
SELECT store_id, ROUND(AVG(amount), 2) AS median_amount
FROM numbered
WHERE rn_asc BETWEEN rn_desc - 1 AND rn_desc + 1
GROUP BY store_id
ORDER BY store_id;
```

**Why it is correct:** when the descending order is the exact reverse of the ascending one, `rn_desc = n + 1 − rn_asc`. So `|rn_asc − rn_desc| = |2·rn_asc − n − 1| ≤ 1` holds exactly for the middle row (odd n, where it is 0) or the two middle rows (even n, where it is 1). No count is needed. This is a well-known interview answer. Its fragility: the tie-break must be reversed too (`order_id DESC`), or the two numberings do not mirror each other within groups of equal amounts.

**Cost model (reasoned, plan shape checked):** the plan shows **two sorts**. MySQL sorts by `(store_id, amount, order_id)` for `rn_asc`, writes a temporary table, then sorts again by `(store_id, amount DESC, order_id DESC)` for `rn_desc`. Each sort is O(N log N), so this does twice the sorting work of approach 3. `indexes.sql` does not remove either sort: MySQL still sorts the window input even when an index has the right order.

### Approach 3 (optimal): ROW_NUMBER + COUNT over one window (`solutions/03_row_number_and_count.sql`)

The SQL is the assembled query in section 4.

**Why it is correct:** `rn` is the 1-based position in (amount, order_id) order, and `n` is the store size (the full-partition frame makes `COUNT` see all of the store's rows, not a running count). The filter keeps the middle row(s), and `AVG` returns the median. `AVG` over `DECIMAL(10,2)` is exact (scale 6), so `ROUND` sees the true midpoint.

**Cost model (reasoned, plan shape checked):** **one sort**, by `(store_id, amount, order_id)`. Then a streaming `ROW_NUMBER` pass and a buffered `COUNT` pass over each partition, which is linear. A detail worth knowing: written as `COUNT(*) OVER (PARTITION BY store_id)`, a different window from the `ROW_NUMBER` one, MySQL plans it as a *separate* window with its own extra sort (checked with `EXPLAIN`). Sharing the named window `w` and giving `COUNT` the full frame keeps it to a single sort. As with approach 2, the index does not remove the window sort.

**Measured** (`gen.py` data, generated by the bench workflow; the table is filled in automatically, so never type numbers here):

<!-- BENCH:45-median-order-amount-per-store -->
_Measured 2026-11-05 by the bench workflow: MySQL 8.0.46, AMD EPYC 9V45 96-Core Processor, 2 vCPU. Median of 3 runs after 1 warm-up; each statement capped at 60 s. Sizes are main-table rows from `gen.py`. Raw numbers and EXPLAIN ANALYZE: `bench/results/45-median-order-amount-per-store.json`._

**Without indexes**

| Solution | 1,000 rows | 100,000 rows | 1,000,000 rows | × slower than optimal @ 1,000,000 |
|---|---:|---:|---:|---:|
| `01_self_join_positions` | 172 ms | timeout >60s | timeout >60s † | > 22× |
| `02_row_number_asc_desc` | 1.92 ms | 94.8 ms | 1.51 s | 0.6× |
| `03_row_number_and_count` (optimal) | 1.3 ms | 99.6 ms | 2.72 s | 1.0× |

† not run at this size: it already timed out at a smaller size.

A ratio below 1.0× means that approach was faster than the one labelled optimal here.

**With `indexes.sql`**

| Solution | 1,000 rows | 100,000 rows | 1,000,000 rows | × slower than optimal @ 1,000,000 |
|---|---:|---:|---:|---:|
| `01_self_join_positions` | 33.1 ms | 5.25 s | timeout >60s | > 23× |
| `02_row_number_asc_desc` | 1.16 ms | 83.8 ms | 1.32 s | 0.5× |
| `03_row_number_and_count` (optimal) | 1.18 ms | 87 ms | 2.62 s | 1.0× |

A ratio below 1.0× means that approach was faster than the one labelled optimal here.

> GitHub-hosted runners are shared, noisy VMs: compare the ratios between rows, not the absolute times.
<!-- /BENCH -->

### Why the optimal one wins

A median needs each row's position in a sorted group, so one sort of the data is the irreducible cost. Approach 3 pays exactly that once: the count rides on the same sorted partition. Approach 2 pays it twice to avoid counting. Approach 1 avoids sorting altogether by counting, for every row, how many rows precede it. That is a sort done the slowest possible way: quadratic within each store, which large stores make visible.

## 6. At scale

**(a) What breaks first.** *Reasoned, then checked by the bench table:* approach 1, with or without the index: its cost is Σ n_s², and one store with 10,000 orders already means 100M comparisons. Next is approach 2's second sort. Approach 3's single sort spills to disk when `sort_buffer_size` is exceeded, which is still O(N log N) with sequential I/O.

**(b) One machine, ~1M–100M rows.**
- `indexes.sql` adds `StoreOrders (store_id, amount, order_id)`. It turns approach 1's subqueries into per-store range reads, from quadratic in the table to quadratic per store. On MySQL 8.0 it does **not** remove the window sort in approaches 2 and 3 (the plans still show `Sort` above the index scan), so measure before expecting a window to benefit from an index.
- The window version materialises every order with its `rn` and `n` before filtering out all but 1–2 rows per store. A store-at-a-time alternative, a correlated `LIMIT 1 OFFSET k`, is not available, because MySQL requires `LIMIT`/`OFFSET` to be literals or prepared-statement parameters, not expressions. A stored procedure looping over stores with a prepared statement can read just the middle rows from the index. That is worth it only when stores are few and huge.
- If medians are needed per day as well, partition the table by date so each run sorts only the new slice; see (d).

**(c) Distributed engines, billions of rows. *Reasoned, not measured.***
- *Why medians hurt:* `SUM` and `COUNT` combine from partial results, but a median does not. The median of medians is not the median. An exact median needs every value of a group in one place, sorted. That means a shuffle of all rows by `store_id`, then a per-partition sort. A skewed store (one flagship with a billion orders) lands on one worker.
- *Approximate answers:* t-digest or KLL sketches (Snowflake `APPROX_PERCENTILE`, Spark `percentile_approx`) are mergeable. Each task builds a small sketch per store, and the sketches combine without moving raw rows, with bounded memory and typically well under 1% rank error. Acceptable for dashboards and anomaly detection; not for anything that is billed, audited or used as a contractual threshold.
- *Exact but cheaper:* if amounts have few distinct values (prices), aggregate to (store, amount, count) first. That is decomposable. Then find the middle by a running sum of counts per store. The sort then runs over distinct amounts, not orders.
- *Global sort:* only the final output is ordered by `store_id`, over one row per store. That is small, so it is fine.

**(d) The data-engineering answer.** An exact median is not incrementally maintainable from a single number, but the **(store, amount, count) histogram** is. Merge each batch into it, and compute medians from the histogram (one row per distinct amount, not per order):

```sql
-- store_amount_hist(store_id, amount, cnt, PRIMARY KEY (store_id, amount)), fed by each batch of new orders.
-- Snowflake / ANSI MERGE (UNVERIFIED):
MERGE INTO store_amount_hist t
USING (SELECT store_id, amount, COUNT(*) AS c FROM new_orders GROUP BY store_id, amount) s
ON t.store_id = s.store_id AND t.amount = s.amount
WHEN MATCHED THEN UPDATE SET cnt = t.cnt + s.c
WHEN NOT MATCHED THEN INSERT (store_id, amount, cnt) VALUES (s.store_id, s.amount, s.c);

-- MySQL equivalent: INSERT ... SELECT ... ON DUPLICATE KEY UPDATE cnt = cnt + VALUES(cnt);

-- Median from the histogram: running counts locate positions (n+1) DIV 2 and n DIV 2 + 1.
WITH h AS (
  SELECT store_id, amount,
         SUM(cnt) OVER (PARTITION BY store_id ORDER BY amount) - cnt + 1 AS first_pos,   -- first position of this amount
         SUM(cnt) OVER (PARTITION BY store_id ORDER BY amount)           AS last_pos,
         SUM(cnt) OVER (PARTITION BY store_id)                           AS n
  FROM store_amount_hist
)
SELECT store_id,
       ROUND((MAX(CASE WHEN (n + 1) DIV 2 BETWEEN first_pos AND last_pos THEN amount END)
            + MAX(CASE WHEN n DIV 2 + 1  BETWEEN first_pos AND last_pos THEN amount END)) / 2, 2) AS median_amount
FROM h
GROUP BY store_id
ORDER BY store_id;
```

The median query was checked once against this folder's edge and differential tests, with the histogram built inline from `StoreOrders`; it is not kept as a solution. The `order_id` tie-break disappears here, and that is fine: it only orders rows with equal amounts, so it never changes the median value. Caveats interviewers probe. *Refunds or cancellations* are −1 on a (store, amount) bucket, and a bucket that reaches 0 should be deleted. *Idempotency:* apply batches by watermark. *Continuous amounts* (no repeated prices) make the histogram as large as the table, so bucket the amounts, or fall back to a sketch.

## 7. Edge cases

Each "breaks" claim below is checked by execution: `mistakes/*.sql` are the tempting wrong queries, and the harness asserts that each one fails every dataset it names (`harness/test_mistakes.py`).

| Case | Dataset | Wrong queries it catches (`mistakes/`) |
|---|---|---|
| Odd (5), even (4) and single-order stores, rows interleaved | `tests/edge_typical.sql` | `mean_not_median` (9.95 instead of 7.25), `odd_case_only` (25.50 instead of 27.75), `decimal_division_positions` (odd stores vanish), `div_middle_off_by_one` (7.13 instead of 7.25) |
| Duplicate amounts at the middle positions | `tests/edge_duplicates.sql` | `rank_instead_of_row_number` (stores 10 and 20 vanish: positions 2 and 3 do not exist), `dense_rank_instead_of_row_number` (store 10 → 9.00), `decimal_division_positions` |
| Midpoints with a third decimal of 5 | `tests/edge_rounding.sql` | `odd_case_only`, `mean_not_median`. The dataset also pins MySQL's exact-`DECIMAL` rounding (10.125 → 10.13); float arithmetic would be at the mercy of binary representation. |
| Empty table | `tests/edge_empty.sql` | none in `mistakes/`. Every approach returns no rows; there is no store to report. |
| Ordering: stores inserted in descending id order, medians falling as id rises | `tests/edge_order.sql` | `odd_case_only` (store 42: 2.00), `decimal_division_positions` (stores 7 and 100 vanish), `div_middle_off_by_one` (store 7: 55.00) |

NULLs: `amount` is `NOT NULL` by spec. If it were nullable, decide first whether a NULL order counts toward n. `COUNT(*)` would count it, while `ORDER BY amount` puts NULLs first in MySQL and would shift every position. The usual answer is to filter `amount IS NOT NULL` before numbering. Ties: handled by `order_id` as the spec requires; the tie-break never changes the median *value*, only which of several equal rows is "the" middle one.

No approach in `solutions/` is broken by any of these. Approach 1 is slow on large stores, not wrong.

## 8. Interviewer follow-ups

1. **"The 90th percentile instead of the median."** Pick a convention, because SQL engines differ. *Nearest rank* is the row at position `CEIL(0.9 × n)`. *Linear interpolation* (`PERCENTILE_CONT`) uses positions `FLOOR(0.9·(n−1)) + 1` and the next one, weighted by the fraction. The median is the one case where the two conventions agree.
2. **"Median across all stores, not per store."** Drop `PARTITION BY`. The window becomes a global sort of the whole table, one worker in a distributed engine. Sketches (section 6c) or the histogram (6d) are the scalable versions.
3. **"Why not `ORDER BY amount LIMIT 1 OFFSET n/2`?"** That is fine for one global median in an application. Per store it would need a correlated `LIMIT` with a computed offset, which MySQL does not allow (`LIMIT` takes literals or parameters only).
4. **"Rolling 7-day median per store."** Frame-based windows cannot compute medians in MySQL (there is no `MEDIAN()` window function). Join each day to its 7-day range of orders and apply the same `ROW_NUMBER` + `COUNT` per (store, day). The rows multiply by the window length; that is the honest cost of an exact moving median. See `29-restaurant-growth` for the moving-window shape.
5. **"Prove your filter keeps exactly one row for odd n."** For n = 2k + 1: `(n+1) DIV 2 = k+1` and `n DIV 2 + 1 = k+1`, so it is one position. For n = 2k: `k` and `k+1`, the two middle positions. With `/`, n = 2k + 1 gives `k + 0.5`, which matches no row; that is `mistakes/decimal_division_positions.sql`.

## 9. Snowflake notes (UNVERIFIED)

`snowflake.sql` uses Snowflake's native aggregate. What changes, and why:

- `MEDIAN(amount)` is an exact median, averaging the two middle values for even n, with NULLs ignored. It is equivalent to `PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY amount)`. The whole positional machinery becomes one `GROUP BY`. Still an exact median, so it has the same data movement as section 6c: every value of a store goes to one place.
- `ROUND` on `NUMBER` rounds half away from zero, matching MySQL's behaviour on `DECIMAL` for this data. Check the result scale of `MEDIAN` on `NUMBER(10,2)` before comparing outputs byte-for-byte.
- `APPROX_PERCENTILE(amount, 0.5)` is the sketch-based alternative for very large groups (t-digest; mergeable; approximate).
- The MySQL window solution also runs on Snowflake unchanged, and `QUALIFY` could replace the CTE for the filter step (`QUALIFY rn IN (…)`). But with `MEDIAN` available, the hand-written version is only interview practice.

## 10. Pattern links

Same "position inside a group" family:
- `44-classify-facilities-by-value`: `NTILE` is position-based bucketing over sorted values. Same tie-break question, same "positions, not values" idea.
- `19-department-top-three-salaries`: `ROW_NUMBER` vs `RANK` vs `DENSE_RANK` decide the answer when values tie, the same choice as the `rank_instead_of_row_number` mistake here.
- `32-human-traffic-of-stadium`: `ROW_NUMBER` used as a sequence position (gaps and islands).

Same "window first, then filter, then aggregate" shape:
- `29-restaurant-growth`: windows over aggregated rows, then filtering by position.
- `20-product-sales-analysis-iii`: first row per key, the simplest positional filter.
