# 08 · Odd and Even Transactions

## 1. Problem & trigger phrases

Original: [Odd and Even Transactions](https://leetcode.com/problems/odd-and-even-transactions/) (LeetCode 3220, medium). Read the statement there; this guide only restates the spec in its own words.

**Spec (own words):** for every date that appears in `transactions`, report two numbers: the total of that day's odd amounts and the total of that day's even amounts. A day with no odd (or no even) amounts shows 0 on that side. Sort by date, oldest first.

| Trigger phrase | What it forces in SQL |
|---|---|
| "odd and even transactions" | Parity is a property of the **amount**, not of `transaction_id`. The word "transactions" invites you to look at the id; the spec says `amount % 2`. Two categories of the same column that you need **side by side** is the signature of a pivot. |
| "for each day" | The output grain is a date: `GROUP BY transaction_date`. Only dates that occur in the table get a row; there is no calendar to fill. |
| "display as 0" | A side with no matching rows must be 0. `SUM` over no non-NULL inputs is NULL, so the zero has to be manufactured: `ELSE 0` inside the `CASE`, or `COALESCE` outside. |

Not in the wording, but forced by it: the output has **two measures from one column**. If you find yourself writing the same `SELECT … GROUP BY` twice with a different `WHERE`, the wording is asking for conditional aggregation instead.

## 2. Schema & grain

| Table | One row means | Columns that matter |
|---|---|---|
| `transactions` | one transaction | `amount` (decides the bucket and is the thing summed), `transaction_date` (the group key). `transaction_id` is a distractor. |

**Output grain:** one row per distinct `transaction_date`. Sanity check: the output row count equals `SELECT COUNT(DISTINCT transaction_date) FROM transactions`, whatever the amounts are.

**Where the grain changes:** transaction grain → day grain, in a single `GROUP BY`. Unlike most problems in this repo there is **no second table and no join**, so the only way to break the grain is to split the problem into two aggregates and then reassemble them (approaches 1 and 2). Every date that has only one parity is a row that exists on one side of that reassembly and not on the other. That is the whole difficulty.

## Assumptions

Confidence is `high`; these are the places the spec says nothing, so the guide picks an interpretation and the edge datasets pin it down.

1. **Negative amounts: parity is mathematical.** -3 is odd. In MySQL `-3 % 2` is `-1`, not `1`, so the odd test is `MOD(amount, 2) <> 0`, never `= 1`. Tested in `tests/edge_negative_and_zero.sql`. Zero is even.
2. **NULL amount: neither odd nor even.** `NULL % 2` is NULL, so the amount joins neither sum. The *date* still exists, so it still gets a row, with `0, 0` if all of its amounts are NULL. Tested in `tests/edge_nulls.sql`. (`schema.sql` makes `amount` nullable for this reason.)
3. **Same-amount transactions on one day are separate transactions.** Both are summed. Tested in `tests/edge_typical.sql`.

## 3. Hint ladder

<details><summary>Hint 1</summary>

Pattern: **pivot by conditional aggregation**. One group key, one measure, two categories that must become two columns.

</details>

<details><summary>Hint 2</summary>

Shape: group the table by date once. For each group you need two sums over the same rows, each counting only the amounts of one parity. No join and no second pass should be needed.

</details>

<details><summary>Hint 3</summary>

Key clause: `SUM(CASE WHEN <parity test> THEN amount ELSE 0 END)`, once per column. The `ELSE 0` is what makes the missing side 0. Test odd with `MOD(amount, 2) <> 0`, not `= 1`, or negative odd amounts fall through. Put `ORDER BY transaction_date` last.

</details>

## 4. Decomposition

Read the output column list first: `transaction_date, odd_sum, even_sum`. One key column and two measures. Then ask which wording produces which part.

1. **Group key: `transaction_date`.**
   *Why a GROUP BY here:* "for each day" with no calendar table means "for each day that appears". A group per distinct date is exactly that, and it guarantees no date is invented or lost.
2. **Bucket test: parity of `amount`.**
   *Why a CASE here, not a filter:* the two sums must come from the **same group**. A `WHERE` on parity would remove the other parity's rows before they reach their own sum, and you would need a second query. A `CASE` inside the aggregate lets one pass compute both.
3. **Missing side: `ELSE 0`.**
   *Why not leave it NULL:* "display as 0". `SUM` of an empty or all-NULL input is NULL; a `CASE` with no `ELSE` yields NULL for every non-matching row. `ELSE 0` makes the non-matching rows contribute a real zero.
4. **Order: `ORDER BY transaction_date`.**
   *Why explicit:* the spec fixes an order; `GROUP BY` does not promise one in MySQL 8.0.

The pieces assemble into the one-pass query (this is `solutions/03_conditional_aggregation.sql`):

```sql
SELECT transaction_date,
       SUM(CASE WHEN MOD(amount, 2) <> 0 THEN amount ELSE 0 END) AS odd_sum,
       SUM(CASE WHEN MOD(amount, 2) =  0 THEN amount ELSE 0 END) AS even_sum
FROM transactions
GROUP BY transaction_date
ORDER BY transaction_date;
```

Self-check: pick a date you know has only odd amounts and confirm `even_sum` is `0`, not NULL. Then check that `odd_sum + even_sum` equals the day's plain `SUM(amount)` (they must agree, since every non-NULL amount is exactly one of the two).

## 5. Approaches: brute force → optimal

### Approach 1: two correlated subqueries per date (`solutions/01_correlated_subqueries.sql`)

```sql
SELECT d.transaction_date,
       COALESCE((SELECT SUM(t.amount) FROM transactions t
                  WHERE t.transaction_date = d.transaction_date AND MOD(t.amount, 2) <> 0), 0) AS odd_sum,
       COALESCE((SELECT SUM(t.amount) FROM transactions t
                  WHERE t.transaction_date = d.transaction_date AND MOD(t.amount, 2) = 0), 0)  AS even_sum
FROM (SELECT DISTINCT transaction_date FROM transactions) d
ORDER BY d.transaction_date;
```

**Why it is correct:** the outer query is the list of dates present, so no date is lost and none is invented. Each subquery sums one parity for one date; a day without that parity gets NULL from the empty `SUM`, and `COALESCE` turns it into 0. It reads exactly like the spec, which is why it is the natural first attempt.

**Cost model (reasoned):** the subqueries are *dependent*: they run once per date, twice. Without an index on `transaction_date`, each run scans the whole table, so the work is about 2 × days × rows. With 1,000 days and 1M rows that is on the order of two billion row visits; the cost grows with *days × rows*, not with rows alone. With the `indexes.sql` index each run reads one date's index entries, and the total becomes roughly linear in rows.

### Approach 2: one aggregate per parity, stitched onto the dates (`solutions/02_two_aggregates_joined.sql`)

```sql
WITH days AS (SELECT DISTINCT transaction_date FROM transactions),
odd_day  AS (SELECT transaction_date, SUM(amount) AS s FROM transactions WHERE MOD(amount, 2) <> 0 GROUP BY transaction_date),
even_day AS (SELECT transaction_date, SUM(amount) AS s FROM transactions WHERE MOD(amount, 2) =  0 GROUP BY transaction_date)
SELECT d.transaction_date, COALESCE(o.s, 0) AS odd_sum, COALESCE(e.s, 0) AS even_sum
FROM days d
LEFT JOIN odd_day  o ON o.transaction_date = d.transaction_date
LEFT JOIN even_day e ON e.transaction_date = d.transaction_date
ORDER BY d.transaction_date;
```

**Why it is correct:** each CTE is at day grain, so both LEFT JOINs are 1:1 from `days` and cannot duplicate rows. `days` carries every date, so a date missing from `odd_day` or `even_day` still survives, and `COALESCE` supplies the 0. Replace either `LEFT JOIN` with `JOIN`, or build the date list from one of the sums, and one-sided days vanish (`mistakes/inner_join_of_parities.sql`).

**Cost model (reasoned):** three scans of `transactions` (the CTEs are referenced once each, so MySQL 8.0 can merge or materialise them), two small hash joins on day-grain rows, no per-date loop. The joins are cheap because the day-grain inputs are small; the cost is the repeated scans of the big table. Linear in rows, with a constant about three times approach 3.

### Approach 3 (optimal): conditional aggregation (`solutions/03_conditional_aggregation.sql`)

The SQL is the assembled query in section 4.

**Why it is correct:** one `GROUP BY` forms exactly one group per date present. Inside a group each `CASE` adds the amounts of one parity and adds 0 for the others, so a missing parity yields a genuine 0. A NULL amount fails both conditions (`NULL <> 0` and `NULL = 0` are both unknown), falls to `ELSE 0`, and still keeps its date's group alive.

**Cost model (reasoned):** one scan, one aggregation keyed by date, two accumulators per group. The memory needed is proportional to the number of distinct dates, not to the number of transactions. With the `indexes.sql` index the scan arrives in date order, so MySQL can aggregate while streaming, with no temporary table.

**Measured** (`gen.py` data, generated by the bench workflow; the table is filled in automatically, so never type numbers here):

<!-- BENCH:08-odd-and-even-transactions -->
_Measured 2026-11-04 by the bench workflow: MySQL 8.0.46, Intel(R) Xeon(R) Platinum 8370C CPU @ 2.80GHz, 2 vCPU. Median of 3 runs after 1 warm-up; each statement capped at 60 s. Sizes are main-table rows from `gen.py`. Raw numbers and EXPLAIN ANALYZE: `bench/results/08-odd-and-even-transactions.json`._

**Without indexes**

| Solution | 1,000 rows | 100,000 rows | 1,000,000 rows | × slower than optimal @ 1,000,000 |
|---|---:|---:|---:|---:|
| `01_correlated_subqueries` | 24.6 ms | timeout >60s | timeout >60s † | > 69× |
| `02_two_aggregates_joined` | 2.28 ms | 130 ms | 1.25 s | 1.4× |
| `03_conditional_aggregation` (optimal) | 1.63 ms | 93.6 ms | 873 ms | 1.0× |

† not run at this size: it already timed out at a smaller size.

**With `indexes.sql`**

| Solution | 1,000 rows | 100,000 rows | 1,000,000 rows | × slower than optimal @ 1,000,000 |
|---|---:|---:|---:|---:|
| `01_correlated_subqueries` | 2.18 ms | 81.2 ms | 671 ms | 1.6× |
| `02_two_aggregates_joined` | 1.81 ms | 72 ms | 627 ms | 1.5× |
| `03_conditional_aggregation` (optimal) | 1.25 ms | 49.1 ms | 420 ms | 1.0× |

> GitHub-hosted runners are shared, noisy VMs: compare the ratios between rows, not the absolute times.
<!-- /BENCH -->

### Why the optimal one wins

Approach 3 reads the table once and never has to reassemble anything, so the "missing side" problem cannot occur: each group already contains both accumulators. Approaches 1 and 2 solve the same problem by splitting and re-joining, which costs extra scans (approach 2) or a per-date loop (approach 1), and each introduces a place where a date can be dropped. The same property carries to distributed engines: a conditional sum is *decomposable*, so each worker pre-aggregates locally and the shuffle moves only partial sums (section 6c).

## 6. At scale

**(a) What breaks first.** *Reasoned, then checked by the bench table:* approach 1 goes first without an index, because its cost is days × rows. Approach 2 degrades next, as three full scans. Approach 3 degrades last and most gently, since it is one scan and its state is two numbers per distinct date.

**(b) One machine, ~1M–100M rows.**
- `indexes.sql` adds `transactions (transaction_date, amount)`. It is *covering*: no other column is read. Approach 1 turns each subquery into a short index range read; approach 3 aggregates in index order.
- The index does **not** help the parity test: `MOD(amount, 2)` is evaluated on each row either way. That is fine, because the filter is not selective (about half the rows pass each side) and the whole index is read anyway.
- A stored generated column `amount_parity` would not remove the need to read `amount` for the sum. Skip it unless parity is also used for filtering elsewhere.
- If the real question is "recent days only", add `WHERE transaction_date >= …` as a half-open range on the raw column; the index lets MySQL read only that slice. Monthly `PARTITION BY RANGE` helps at 100M+ rows, at the cost of putting the partition key into every unique key (`transaction_id` alone would no longer be the PK).

**(c) Distributed engines, billions of rows. *Reasoned, not measured.***
- *Shuffle:* the group key is a date, so the number of groups is small (days, not rows). A Spark-style engine pre-aggregates each task's partition into at most one row per date, then shuffles those partial rows by date. The shuffle volume is about *tasks × days* rows regardless of table size. `SUM` is decomposable, which is what makes this work.
- *Skew:* one date holding a large share of rows (a sale day, a batch load stamped with one date) would overload one reducer in a naive plan. Partial aggregation removes it, because that date leaves each task as a single row.
- *Pruning:* in Snowflake, a transaction table usually arrives roughly in date order, so micro-partitions are naturally clustered on `transaction_date` and a date-range predicate skips most of them. Late-arriving data erodes that; a clustering key on the date restores it at a reclustering cost.
- *Things to avoid:* approach 2's repeated scans; approach 1's per-date loop, which engines often cannot decorrelate into a single pass for a `SUM` with a parity filter (check the plan). No `COUNT DISTINCT` is involved, so there is no approximate-function question here. A global `ORDER BY` is only over the day-grain result (thousands of rows), which is cheap. The expensive sort would be over the raw table.

**(d) The data-engineering answer.** Sums by date are additive, so they can be maintained incrementally instead of recomputed. Keep a day-grain summary table and fold each new batch into it:

```sql
-- daily_parity_sums(transaction_date DATE PRIMARY KEY, odd_sum BIGINT, even_sum BIGINT)
-- Snowflake / ANSI MERGE (UNVERIFIED):
MERGE INTO daily_parity_sums t
USING (SELECT transaction_date,
              SUM(IFF(MOD(amount, 2) <> 0, amount, 0)) AS odd_sum,
              SUM(IFF(MOD(amount, 2) =  0, amount, 0)) AS even_sum
       FROM transactions_batch             -- only rows not yet applied (by transaction_id watermark)
       GROUP BY transaction_date) s
ON t.transaction_date = s.transaction_date
WHEN MATCHED THEN UPDATE SET odd_sum = t.odd_sum + s.odd_sum, even_sum = t.even_sum + s.even_sum
WHEN NOT MATCHED THEN INSERT (transaction_date, odd_sum, even_sum) VALUES (s.transaction_date, s.odd_sum, s.even_sum);

-- MySQL equivalent (no MERGE; VALUES() is deprecated since 8.0.20 but still the form that works with INSERT ... SELECT):
INSERT INTO daily_parity_sums (transaction_date, odd_sum, even_sum)
SELECT transaction_date,
       SUM(CASE WHEN MOD(amount, 2) <> 0 THEN amount ELSE 0 END),
       SUM(CASE WHEN MOD(amount, 2) =  0 THEN amount ELSE 0 END)
FROM transactions_batch GROUP BY transaction_date
ON DUPLICATE KEY UPDATE odd_sum = odd_sum + VALUES(odd_sum), even_sum = even_sum + VALUES(even_sum);
```

Caveats interviewers probe. *Idempotency*: a batch applied twice double-adds, so track applied ids with a watermark and make a re-run a no-op. *Corrections*: if an amount or date is edited, subtract the old row from its old day and add the new row to its new day (a CDC feed with before and after images). *Late data* needs no special handling here, because the summary is keyed by the transaction's own date rather than by load time.

## 7. Edge cases

Each "breaks" claim below is checked by execution: `mistakes/*.sql` are the tempting wrong queries, and the harness asserts that each one fails every dataset it names (`harness/test_mistakes.py`).

| Case | Dataset | Wrong queries it catches (`mistakes/`) |
|---|---|---|
| Day with only odd, or only even, amounts | `tests/edge_one_side_missing.sql` | `no_else_zero` (NULL instead of 0), `inner_join_of_parities` (day vanishes) |
| Negative odd amount (`-3 % 2` is `-1`) | `tests/edge_negative_and_zero.sql` | `modulo_equals_one` (negative odds are silently dropped) |
| Zero amount; a day containing only a zero | `tests/edge_negative_and_zero.sql` | `no_else_zero`, `inner_join_of_parities` (the zero-only day has no odd side) |
| NULL amount, including a day with only NULL amounts | `tests/edge_nulls.sql` | `where_drops_null_only_days` (the day disappears), `no_else_zero`, `inner_join_of_parities` |
| Two transactions with the same amount on one day; ids whose parity disagrees with the amount's | `tests/edge_typical.sql` | `sum_distinct` (collapses duplicates), `parity_of_transaction_id` |
| Empty table | `tests/edge_empty.sql` | `ungrouped_total` (one row of NULLs instead of none) |
| Scrambled insertion order, year and month boundaries | `tests/edge_ordering.sql` | `order_by_desc` |

No approach in `solutions/` is broken by any of these; approach 1 is only slow, never wrong.

## 8. Interviewer follow-ups

1. **"Make it a third column: total."** `SUM(amount)`, which equals `odd_sum + even_sum` only if you treat NULL amounts as absent (they are, in both). Say the identity out loud; it doubles as a test.
2. **"Now by month, and give me months with no transactions too."** That changes the grain to a calendar. A month with no rows exists nowhere in the table, so you need a month scaffold (generated series or a calendar table) LEFT JOINed to the aggregate. Same pattern as `09-count-salary-categories` and `30-calculate-a-rolling-average-of-total-revenue`.
3. **"Unknown number of categories, not just two."** Conditional aggregation needs the column list at write time. For a dynamic list you generate the SQL (prepared statement in MySQL, `PIVOT ... ANY` or dynamic SQL elsewhere), or return the long format `(date, parity, sum)` and let the consumer pivot. The long format is also the better warehouse model.
4. **"Why `MOD(amount, 2) <> 0` instead of `= 1`?"** Negative operands. The remainder takes the sign of the dividend in MySQL (and in most engines), so `-3 % 2 = -1`. `<> 0` is correct for every integer; `= 1` is correct only for non-negative ones.
5. **"Could you use a `UNION ALL` of two grouped queries and then regroup?"** Yes: a `UNION ALL` of `(date, amount, 0)` and `(date, 0, amount)` rows and a `SUM` over it works, and is the unpivot-then-pivot idea. It does the work of conditional aggregation with an extra pass, so it only makes sense when each branch needs its own source.

## 9. Snowflake notes (UNVERIFIED)

`snowflake.sql` keeps the shape of approach 3. What changes, and why:

- `IFF(cond, a, b)` replaces `CASE WHEN … THEN … ELSE … END`; the semantics are the same, including that a NULL condition takes the else branch.
- `MOD` follows the sign of the dividend there as well, so the `<> 0` test is still the right one. Check this on your own negative data before relying on it in an interview.
- A `PIVOT` clause could express the two columns, but it needs an explicit list of pivot values and a parity expression to pivot on, which makes it longer than two conditional sums for no gain. `COUNT_IF(cond)` exists for counts but not for sums.
- Performance comes from **pruning and a single scan**, not indexes: there are no secondary indexes, so `indexes.sql` has no equivalent. Filter the date column as a raw-column range so micro-partitions can be skipped.
- Unquoted identifiers are upper-cased: `odd_sum` returns as `ODD_SUM`.

## 10. Pattern links

Same pattern (pivot via conditional aggregation, `ELSE 0`):
- `04-monthly-transactions-i`: several conditional counts and sums in one `GROUP BY`.
- `10-find-drivers-with-improved-fuel-efficiency`: pivot into two buckets (half-years), then compare them.
- `11-analyze-subscription-conversion`: pivot per user by activity type, with a "both present" filter.

Contrast:
- `09-count-salary-categories`: here the missing categories are rows that don't exist at all, so a CASE cannot make them; a scaffold has to be joined on.
- `01-market-analysis-i`: zero-instead-of-NULL again, but through a LEFT JOIN rather than `ELSE 0`.
