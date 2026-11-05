# 21 · Product Price at a Given Date

## 1. Problem & trigger phrases

Original: [Product Price at a Given Date](https://leetcode.com/problems/product-price-at-a-given-date/) (LeetCode 1164, medium). Read the statement there; this guide only restates the spec in its own words.

**Spec (own words):** the table lists price *changes* (product, new price, date of the change). For every distinct product, report its price on 2019-08-16: the new price from its most recent change dated on or before that day. A product with no such change still has its original price of 10. Output `product_id` and `price`.

| Trigger phrase | What it forces in SQL |
|---|---|
| "Initially, all products have price 10" | A **default for the missing case**. Products with no change on/before the date have no qualifying row, so a query that only filters the change table loses them. Either start from the set of distinct products and `LEFT JOIN` (then `COALESCE(…, 10)`), or `UNION` the unchanged products back in with the literal 10. |
| "prices … on the date 2019-08-16" | An **as-of lookup**: the latest change with `change_date <= '2019-08-16'`. Inclusive, so a change dated exactly that day is in effect. "Latest" means the greatest date, not the greatest price. |

Not in the wording: the date is a fixed constant here. The same shape works with a parameter or with a date column from another table (an as-of join).

## 2. Schema & grain

| Table | One row means | Keys that matter here |
|---|---|---|
| `Products` | one price change of one product on one date | `(product_id, change_date)` is the primary key; `new_price` is the value that takes effect on `change_date` |

**Output grain:** one row per **distinct `product_id`** in `Products`. The input is at *change* grain (a product has one row per change), so the output is a *coarser* grain than the input, and every product must survive even if all its changes are later than the date.

**Where the grain changes:** the query reduces each product's history to one row. It does this by picking the latest row at or before the date, a "latest per key under a filter" step. The trap is that the filter (`change_date <= …`) is applied to rows, and a product can lose *all* of its rows to that filter. A product that disappears there cannot be recovered later unless the product set is taken from an unfiltered source. That is the grain bug of this problem: **the set of products must be computed before the date filter**.

## 3. Hint ladder

<details><summary>Hint 1</summary>

Pattern: **latest-per-key as of a date, with a default**. Pick the most recent record on or before a cut-off for each key; keys with no such record fall back to a constant.

</details>

<details><summary>Hint 2</summary>

Shape: (1) get the list of all distinct products (before any date filter). (2) From the changes dated on or before the target day, find each product's latest one. (3) Attach (2) to (1) so that products without a row get a NULL. (4) Replace NULL with 10.

</details>

<details><summary>Hint 3</summary>

Key trick: the product list must come from an **unfiltered** read of the table, otherwise products whose changes are all later simply vanish. In a single pass this means computing, per product, `MAX(CASE WHEN change_date <= cutoff THEN change_date END)` as a window or aggregate: it is NULL when no change qualifies, and the final `COALESCE(price, 10)` handles that. Use `<=`, not `<`.

</details>

## 4. Decomposition

"Price on a date" for "every product": a *list of products* and an *as-of lookup* per product.

1. **`last_date`: for each product, the latest change date on or before the target date (or NULL).**
   *Why a conditional aggregate in a window here:* the filter on the date must not remove rows, because a row that fails the filter still tells us the product exists. `MAX(CASE WHEN change_date <= cutoff THEN change_date END) OVER (PARTITION BY product_id)` computes "the latest qualifying date" and puts it on every row of the product; for a product with no qualifying change, it is NULL.
2. **Pick the price on that date.**
   *Why a GROUP BY here:* the product's rows are collapsed to one. `MAX(CASE WHEN change_date = last_date THEN new_price END)` takes the price of the one row on `last_date` (unique, because `(product_id, change_date)` is a key); with `last_date` NULL, the comparison is never true and the result is NULL.
3. **`COALESCE(…, 10)`.**
   *Why a COALESCE here:* "initially 10" is the answer exactly when step 2 found nothing.

```sql
SELECT product_id,
       COALESCE(MAX(CASE WHEN change_date = last_date THEN new_price END), 10) AS price   -- steps 2 + 3
FROM (
  SELECT product_id, new_price, change_date,
         MAX(CASE WHEN change_date <= '2019-08-16' THEN change_date END)
           OVER (PARTITION BY product_id) AS last_date                                   -- step 1
  FROM Products
) t
GROUP BY product_id;
```

This assembly is approach 2, the one-pass form, chosen because it shows every step. On MySQL it measures slowest (about 2.2× the others at 1M rows; section 5). Approach 3 keeps step 3 and replaces steps 1–2 with one correlated "latest change on or before the date" lookup per distinct product.

Self-check before you submit: the number of output rows equals `SELECT COUNT(DISTINCT product_id) FROM Products`. Then find one product whose only changes are after the date and confirm it shows 10.

## 5. Approaches: brute force → optimal

### Approach 1: two groups, UNION ALL (`solutions/01_union_changed_and_unchanged.sql`)

```sql
SELECT p.product_id, p.new_price AS price
FROM Products p
JOIN (SELECT product_id, MAX(change_date) AS last_date FROM Products
       WHERE change_date <= '2019-08-16' GROUP BY product_id) l
  ON l.product_id = p.product_id AND l.last_date = p.change_date
UNION ALL
SELECT product_id, 10 FROM Products GROUP BY product_id HAVING MIN(change_date) > '2019-08-16';
```

**Why it is correct:** every product falls in exactly one of two disjoint groups: it has a change on or before the date (first branch) or its earliest change is after the date (second branch; `HAVING MIN(change_date) > …` is true exactly when no change qualifies). `UNION ALL` is safe because the groups cannot overlap. The join back on `(product_id, change_date)` returns exactly one row per product.

**Cost model (from the bench's EXPLAIN ANALYZE at 1M rows):** on paper, three reads of `Products`: the filtered `GROUP BY MAX`, the join back, and the `GROUP BY … HAVING` in the second branch. In practice MySQL runs **both group-bys as skip scans** of the primary key (*covering index skip scan for grouping*): it jumps through `(product_id, change_date)` one product at a time instead of reading every row. The join back is a primary-key lookup per product. So the "three passes" cost far less than three full scans, and this approach measures as fast as approach 3 (section 5 table). The real cost is maintenance: any change in the date logic has to be made in two branches. This multi-pass UNION is the classic textbook answer and a natural first attempt.

### Approach 2: one scan, window + conditional aggregate (`solutions/02_one_scan_window_pivot.sql`)

The SQL is the assembled query in section 4.

**Why it is correct:** the window gives each row its product's latest qualifying date (NULL if none) without removing any row, so the `GROUP BY product_id` still sees every product. The conditional `MAX` picks the single row on that date. `COALESCE` handles the NULL. There is exactly one output row per distinct product by construction.

**Cost model (reasoned):** one scan of `Products`, with every row going through the window evaluation, into a window partitioned by `product_id`, then a group-by on the same key. There is no join and no second read. In theory the rows already arrive grouped by `product_id` (the primary key provides that order), so no sort is needed. The bench's plan shows otherwise. MySQL scans and **sorts** by `product_id` anyway, with or without `indexes.sql`. Then a *window aggregate with buffering* (about 2.6 s of the total at 1M rows) materialises all 1M rows, and an aggregate using a temporary table groups them again. It is about 2.2× approach 3 at 1M rows.

### Approach 3 (optimal): correlated lookup per product (`solutions/03_correlated_latest.sql`)

```sql
SELECT p.product_id,
       COALESCE((SELECT x.new_price FROM Products x
                  WHERE x.product_id = p.product_id AND x.change_date <= '2019-08-16'
                  ORDER BY x.change_date DESC LIMIT 1), 10) AS price
FROM (SELECT DISTINCT product_id FROM Products) p;
```

**Why it is correct:** the outer query is the unfiltered list of distinct products, so no product can be lost. The subquery returns the price of the latest qualifying change, or no row (NULL) when none qualifies, and `COALESCE` supplies 10. It reads like the spec, one product at a time, which is why many people write it first; it is listed last here because on this schema (primary key `(product_id, change_date)`) it is the one that exploits the physical order.

**Cost model (reasoned):** one subquery per distinct product. Without an index on `product_id`, each execution scans the table and sorts the qualifying rows, so the cost is products × rows. The primary key `(product_id, change_date)` already lets MySQL find a product's changes, so even without `indexes.sql` each probe reads one product's rows, not the whole table; whether the plan reads backward from the date boundary and stops at the first row (cheap) is something to read in `EXPLAIN`. (The bench's EXPLAIN ANALYZE shows only the outer skip scan that lists the distinct products, about 0.36 s at 1M rows; the remaining ~2.2 s is the 235K subquery executions, which the plan text does not break down.)

**Measured** (`gen.py` data, generated by the bench workflow; the table is filled in automatically, so never type numbers here):

<!-- BENCH:21-product-price-at-a-given-date -->
_Measured 2026-11-04 by the bench workflow: MySQL 8.0.46, AMD EPYC 7763 64-Core Processor, 2 vCPU. Median of 3 runs after 1 warm-up; each statement capped at 60 s. Sizes are main-table rows from `gen.py`. Raw numbers and EXPLAIN ANALYZE: `bench/results/21-product-price-at-a-given-date.json`._

**Without indexes**

| Solution | 1,000 rows | 100,000 rows | 1,000,000 rows | × slower than optimal @ 1,000,000 |
|---|---:|---:|---:|---:|
| `01_union_changed_and_unchanged` | 2.85 ms | 304 ms | 2.36 s | 0.9× |
| `02_one_scan_window_pivot` | 3.27 ms | 262 ms | 5.77 s | 2.2× |
| `03_correlated_latest` (optimal) | 2.85 ms | 228 ms | 2.62 s | 1.0× |

A ratio below 1.0× means that approach was faster than the one labelled optimal here.

**With `indexes.sql`**

| Solution | 1,000 rows | 100,000 rows | 1,000,000 rows | × slower than optimal @ 1,000,000 |
|---|---:|---:|---:|---:|
| `01_union_changed_and_unchanged` | 2.83 ms | 217 ms | 2.63 s | 1.0× |
| `02_one_scan_window_pivot` | 3.32 ms | 263 ms | 5.8 s | 2.2× |
| `03_correlated_latest` (optimal) | 2.85 ms | 230 ms | 2.61 s | 1.0× |

> GitHub-hosted runners are shared, noisy VMs: compare the ratios between rows, not the absolute times.
<!-- /BENCH -->

### Why the optimal one wins

It wins on clarity and robustness, and on speed only at 100K rows; the bench does not support a clear speed claim at 1M. Approach 3 asks the question the way the data is stored: the primary key `(product_id, change_date)` keeps each product's changes in date order, so "latest change on or before the date" is one probe per product, and the default case is one `COALESCE` with no second branch. Measured: at 100K rows approach 3 is the fastest (approach 1 is 1.3×). At 1M rows approach 1 is about 10% faster without `indexes.sql`, and the two tie with it. The reason is that MySQL turns approach 1's two `GROUP BY`s into skip scans over the same primary key, so the "multi-pass" textbook answer exploits the ordered storage just as well. Approach 2, the single-pass window, is the clear loser on MySQL (about 2.2× at 1M), because the window buffers, sorts and materialises every row. This is a physical-design result. With a table that lacks the `(product_id, change_date)` key, both approach 1's skip scans and approach 3's probes lose their advantage (reasoned).

## 6. At scale

**(a) What breaks first.** *Measured to 1M rows, reasoned beyond:* approach 2 first: it pushes every row through a buffered window, then materialises and re-aggregates them (about 2.2× the others at 1M). Approaches 1 and 3 both lean on the primary key's order (skip scans and per-product probes) and stay level with each other. Without that key (reasoned), approach 3's probes become scans, products × rows, and it degrades first.

**(b) One machine, ~1M–100M rows.**
- The primary key `(product_id, change_date)` already orders each product's history by date, which is what every approach needs. `indexes.sql` adds `new_price` to make a covering index, so the query never touches the base table. Measured, it changes nothing: every approach runs in the same time with and without it. The clustered primary key already holds `new_price`, because InnoDB stores the row in the primary key.
- For a table where products have *long* histories, the backward probe in approach 3 reads only the newest qualifying row, so it should pull ahead as histories grow (reasoned; the bench data has about 4 changes per product, and there approach 1 keeps up). This is a case where the index order, not the SQL shape, decides.
- If the date is always "today", filter on a recent window of changes first, since older rows can only matter for products without a recent change (a two-step query), or keep the current price in a separate table (section 6d).

**(c) Distributed engines, billions of rows. *Reasoned, not measured.***
- *Shuffle:* all approaches have to bring one product's rows together. The window plan shuffles the whole table once by `product_id`. The aggregate-then-join plan (approach 1) can pre-aggregate `MAX(change_date)` per product locally, shuffling one row per (worker, product), then needs the second pass to fetch the price at that date, which is a join back on both keys (a second shuffle, or a broadcast if the aggregate is small).
- *Skew:* hot products with enormous histories (e.g. a price feed updated every second) would overload one worker in the window plan; the local pre-aggregation in approach 1 is the skew-resistant shape.
- *Snowflake:* `QUALIFY ROW_NUMBER() … = 1` on the date-filtered rows, then a left join from the distinct product list. If the table is clustered by `change_date`, the date filter prunes micro-partitions, but the product list needs an unfiltered read of `product_id`, which is cheap on a columnar store (it reads one column).
- *Things to avoid:* a global sort, and `MAX_BY(new_price, change_date)` without the date filter (it returns the overall latest price, not the price on the date).

**(d) The data-engineering answer.** As-of lookups over a change log are a classic **slowly changing dimension** problem. Store validity intervals instead of single dates (`valid_from`, `valid_to`) so that "price on date D" becomes a point query `valid_from <= D AND D < valid_to` that needs no ranking at all:

```sql
-- price_history(product_id, price, valid_from, valid_to)   -- valid_to is NULL / 9999-12-31 for the current row
-- Maintained incrementally from a change feed: close the open interval, open a new one.
-- Snowflake / ANSI MERGE (UNVERIFIED), per batch containing at most one new change per product:
MERGE INTO price_history t
USING (SELECT product_id, new_price, change_date FROM price_changes_batch) s
ON t.product_id = s.product_id AND t.valid_to IS NULL
WHEN MATCHED AND s.change_date > t.valid_from THEN UPDATE SET valid_to = s.change_date;
-- (second statement) INSERT the new open intervals:
INSERT INTO price_history (product_id, price, valid_from, valid_to)
SELECT product_id, new_price, change_date, NULL FROM price_changes_batch;

-- The question becomes a point lookup with a default:
SELECT d.product_id, COALESCE(h.price, 10) AS price
FROM (SELECT DISTINCT product_id FROM price_history) d
LEFT JOIN price_history h
  ON h.product_id = d.product_id AND h.valid_from <= '2019-08-16'
 AND (h.valid_to IS NULL OR '2019-08-16' < h.valid_to);
```

Caveats interviewers probe: late-arriving or back-dated changes split an existing interval (a MERGE that only closes the *open* interval is wrong for them); two changes on the same day need a rule; and the first interval for a product should be inserted with `valid_from` = the beginning of time at price 10 if "initially 10" is data rather than a constant.

## 7. Edge cases

Each "breaks" claim below is checked by execution: `mistakes/*.sql` are the tempting wrong queries, and the harness asserts that each one fails every dataset it names (`harness/test_mistakes.py`).

| Case | Dataset | Wrong queries it catches (`mistakes/`) |
|---|---|---|
| Several changes before the date; one before and one after; only a later change; a price that dropped | `tests/edge_typical.sql` | `inner_join_drops_default` (the later-only product disappears), `max_price_not_latest` (price drop), `latest_overall_then_filter` |
| A change dated exactly on the target date; the day before; the day after | `tests/edge_boundary_date.sql` | `strict_less_than` (excludes the change dated that day), `inner_join_drops_default`, `latest_overall_then_filter` |
| No change on or before the date for any product | `tests/edge_all_after.sql` | `inner_join_drops_default` (returns nothing) |
| Changes in earlier/later years; price 0; an explicit price equal to the default | `tests/edge_other_years.sql` | `inner_join_drops_default`, `latest_overall_then_filter` |
| `Products` empty | `tests/edge_empty.sql` | none; the product list is empty, so no row (and no default) is produced |

No approach in `solutions/` is broken by any of these. NULLs are outside the spec: all columns are `NOT NULL` in `schema.sql`, and the spec says the price is never NULL.

## 8. Interviewer follow-ups

1. **"Make the date a parameter / a column from another table."** The cut-off moves into the `CASE` or the `ON` clause. With a date per row (an as-of join between two tables), the correlated form generalises directly; the window form needs the joined date on every row first.
2. **"Why `UNION ALL` and not `UNION`?"** The two branches are disjoint by construction, so de-duplication is wasted work (a sort or hash over the result). With `UNION`, a bug that produced duplicates would be hidden instead of showing up in the row count.
3. **"What if two changes can have the same date?"** The primary key forbids it here. If it did not, "latest" needs a tie-break column (e.g. an event id), or the conditional `MAX` would pick the larger price arbitrarily.
4. **"Return prices for several dates at once."** Cross join a date list with the distinct products, then run the as-of lookup per (product, date). That is the point where the interval table in section 6d, or a range join, is clearly better than re-ranking per date.
5. **"What if the initial price differs per product?"** The constant 10 becomes a lookup in a product master table: `COALESCE(h.price, m.initial_price)` with a `LEFT JOIN` to the master. That also removes the dependence on `Products` as the source of the product list (a product with no changes at all would otherwise not exist here).

## 9. Snowflake notes (UNVERIFIED)

`snowflake.sql` uses `QUALIFY` for the as-of lookup and a left join for the default, rather than the window-plus-pivot of approach 2. (On MySQL the primary-key probe of approach 3 is the one that exploits ordered storage; Snowflake has no such ordered key, so the window is the natural form there.) What changes, and why:

- `QUALIFY ROW_NUMBER() OVER (PARTITION BY product_id ORDER BY change_date DESC) = 1` is the idiomatic latest-per-key. It sits inside a subquery that already applies the date filter, then the product list is attached with a left join. Same result as the MySQL approaches, in more readable form.
- `MAX_BY(new_price, change_date)` is tempting for "price at the latest date", but it needs the date filter applied first (`MAX_BY(IFF(change_date <= …, new_price, NULL), IFF(change_date <= …, change_date, NULL))`): it ignores NULLs in the ordering argument, which should be verified before relying on it.
- No secondary indexes; clustering on `product_id` keeps a product's changes together, which helps the window.
- Date literals: `'2019-08-16'::DATE` removes any dependence on session date-format settings.

## 10. Pattern links

Same pattern (latest/first row per key, with a rule for the key that has none):
- `20-product-sales-analysis-iii`: first row per key, keeping every tied row; no default needed.
- `22-find-students-who-improved`: first and last row per group, compared.
- `23-game-play-analysis-iv`: first date per player as an anchor.
- `36-find-churn-risk-customers`: latest row per customer against history.
- `01-market-analysis-i`: the same "keep every key, default for the missing case" requirement, solved by an outer join and `COALESCE`.
