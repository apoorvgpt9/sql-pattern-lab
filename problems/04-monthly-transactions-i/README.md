# 04 · Monthly Transactions I

## 1. Problem & trigger phrases

Original: [Monthly Transactions I](https://leetcode.com/problems/monthly-transactions-i/) (LeetCode 1193, medium). Read the statement there; this guide only restates the spec in its own words.

**Spec (own words):** for each combination of calendar month and country that appears in the data, report four numbers: how many transactions there were, how many were approved, the total amount of all of them, and the total amount of the approved ones. The month is a `YYYY-MM` string.

| Trigger phrase | What it forces in SQL |
|---|---|
| "for each month and country" | The output grain is a **derived key**: `GROUP BY` the month label (a function of `trans_date`) and `country`. Only combinations present in the data appear; there is no calendar to preserve, so no outer join is needed. |
| "number of approved transactions" | A count of a *subset* of the same group, **next to** the unrestricted count. That is conditional aggregation: `SUM(state = 'approved')`, in the same pass as `COUNT(*)`. A `WHERE` would restrict both numbers. |
| "their total amount" | The same idea for amounts: `SUM(CASE WHEN state = 'approved' THEN amount ELSE 0 END)`. The `ELSE 0` is what keeps a group with no approved row at 0 instead of NULL. |

What is **not** in the wording: any filter by date range or by country, any ordering, any ranking.

## 2. Schema & grain

| Table | One row means | Keys that matter here |
|---|---|---|
| `Transactions` | one transaction | `id` (PK); `trans_date` → month; `country`; `state`; `amount` |

**Output grain:** one row per distinct `(month, country)` present in `Transactions`. Row count = number of distinct pairs, so an empty table gives an empty result.

**Where the grain changes:** transaction grain → `(month, country)` grain, in a single `GROUP BY`. The trap is the *second* grain hiding inside each group: "all rows" and "approved rows". They are two measures over the same group, not two groups. If you compute them with separate queries (a filter, then a join), you have to re-align the two on the group key, which is exactly where `NULL` countries and missing groups break.

**Where NULL lives:** `country` can be NULL. `GROUP BY` treats all NULLs as one group, so NULL-country rows form their own group per month and appear in the output with `country = NULL`. Equality joins do not: `NULL = NULL` is not true.

## Assumptions

Confidence is `medium`: the NULL-country behaviour comes from community discussion of the hidden tests, not from the statement text. State and test each interpretation:

1. **A NULL `country` is its own group** (per month), reported with `country = NULL`, never dropped and never merged with a real country. Tested by `tests/edge_null_country.sql`; `count_country_column` and `join_on_plain_equality` show how it breaks.
2. **`state`, `amount` and `trans_date` are NOT NULL.** The original declares `state` as an enum and the spec lists no NULL rule for the others, so there is no "NULL month" group and no NULL amount to skip. If `amount` could be NULL, `SUM` would skip it and `approved_total_amount` for an all-NULL group would be NULL: this repo does not cover that.
3. **`approved_count` and `approved_total_amount` are 0 (not NULL)** for a group with no approved row. Tested by `tests/edge_no_approved.sql`; `case_without_else` shows how it breaks.
4. **Month label** is `YYYY-MM` of `trans_date`, zero-padded. A given calendar month in two different years is two groups (`edge_month_boundaries`).
5. **Amounts are integers and not capped**, so sums are exact. Output order is not specified, so rows are compared as a set.

## 3. Hint ladder

<details><summary>Hint 1</summary>

Pattern: **conditional aggregation**. One `GROUP BY` over a derived key, with several aggregates that each look at a different subset of the same group.

</details>

<details><summary>Hint 2</summary>

Shape: (1) turn each date into a month label. (2) Group by `(month label, country)`. (3) In the one SELECT, compute: all rows counted, approved rows counted, all amounts summed, approved amounts summed. No second query, no join.

</details>

<details><summary>Hint 3</summary>

Key trick: a comparison is 0 or 1 in MySQL, so `SUM(state = 'approved')` counts approved rows (not `COUNT(state = 'approved')`, which counts every row because neither 0 nor 1 is NULL). For the amount use `SUM(CASE WHEN state = 'approved' THEN amount ELSE 0 END)`, with the `ELSE 0`. Count with `COUNT(*)`, not `COUNT(country)`.

</details>

## 4. Decomposition

Read "for each X and Y, report A, B, C, D" as: *one* GROUP BY on X and Y, with four aggregates. Look for which of A–D need a subset of the group; those are the conditional ones.

1. **`labelled`: derive the group key from the date.**
   *Why a function here, not a join:* "for each month" with no mention of months that have no data means only months present matter, so a label computed from `trans_date` is enough. No calendar table, so no outer join. `DATE_FORMAT(trans_date, '%Y-%m')` carries the year, so Jan 2019 and Jan 2020 stay separate.
2. **Final: `GROUP BY month, country`.**
   *Why a GROUP BY here:* the answer is one row per `(month, country)` and the input is one row per transaction. NULL countries group together automatically.
3. **Final: four aggregates in the same SELECT.**
   *Why conditional aggregation here:* "approved" is a subset of the group being measured, so the restriction belongs inside the aggregate (`SUM(state = 'approved')`, `SUM(CASE WHEN … THEN amount ELSE 0 END)`). A `WHERE state = 'approved'` would shrink the group and corrupt the "all" numbers; a second query would need joining back on a NULL-able key.
4. **Zero, not NULL, when nothing is approved.**
   *Why `ELSE 0`:* `SUM` of only NULLs is NULL. The boolean form `SUM(state = 'approved')` is never NULL on a non-empty group, so it needs no guard.

```sql
WITH labelled AS (                              -- step 1: derive the group key
  SELECT DATE_FORMAT(trans_date, '%Y-%m') AS month, country, state, amount
  FROM Transactions
)
SELECT month, country,                          -- step 2: group
       COUNT(*)                                                  AS trans_count,        -- step 3
       SUM(state = 'approved')                                   AS approved_count,
       SUM(amount)                                               AS trans_total_amount,
       SUM(CASE WHEN state = 'approved' THEN amount ELSE 0 END)  AS approved_total_amount  -- step 4
FROM labelled
GROUP BY month, country;
```

`solutions/03_conditional_aggregation.sql` is the same query without the CTE (a CTE here only names the key; it adds no work).

Self-check: summing `trans_count` over the output must equal `SELECT COUNT(*) FROM Transactions`, including the NULL-country group. In every output row `approved_count <= trans_count` and `approved_total_amount <= trans_total_amount` (amounts are non-negative here).

## 5. Approaches: brute force → optimal

### Approach 1: distinct groups + four correlated subqueries (`solutions/01_distinct_groups_subqueries.sql`)

```sql
SELECT g.month, g.country,
       (SELECT COUNT(*) FROM Transactions t
         WHERE DATE_FORMAT(t.trans_date, '%Y-%m') = g.month AND t.country <=> g.country) AS trans_count,
       (SELECT COUNT(*) FROM Transactions t
         WHERE DATE_FORMAT(t.trans_date, '%Y-%m') = g.month AND t.country <=> g.country
           AND t.state = 'approved') AS approved_count,
       (SELECT SUM(t.amount) FROM Transactions t
         WHERE DATE_FORMAT(t.trans_date, '%Y-%m') = g.month AND t.country <=> g.country) AS trans_total_amount,
       (SELECT COALESCE(SUM(t.amount), 0) FROM Transactions t
         WHERE DATE_FORMAT(t.trans_date, '%Y-%m') = g.month AND t.country <=> g.country
           AND t.state = 'approved') AS approved_total_amount
FROM (SELECT DISTINCT DATE_FORMAT(trans_date, '%Y-%m') AS month, country FROM Transactions) g;
```

**Why it is correct:** the derived table lists every `(month, country)` that exists, once; each subquery recomputes one number for exactly that group. `<=>` is null-safe equality, which is what lets the NULL-country group find its own rows (`country = NULL` would match nothing, giving 0 and NULL). `COALESCE` supplies the 0 for a group with no approved rows. It reads like the spec, hence a natural first attempt.

**Cost model (reasoned):** one pass to build the distinct groups, then four dependent subqueries per group, each of which scans for its group's rows. Without a usable index the cost is groups × rows × 4, which grows with both the data and the number of groups. The expression `DATE_FORMAT(trans_date, …)` on the left of the comparison hides the column from a plain index on `trans_date`; only a functional index on that exact expression (see `indexes.sql`) turns each probe into an index range read.

### Approach 2: two aggregates, joined (`solutions/02_two_aggregates_join.sql`)

```sql
WITH totals AS (
  SELECT DATE_FORMAT(trans_date, '%Y-%m') AS month, country,
         COUNT(*) AS trans_count, SUM(amount) AS trans_total_amount
  FROM Transactions GROUP BY DATE_FORMAT(trans_date, '%Y-%m'), country
), approved AS (
  SELECT DATE_FORMAT(trans_date, '%Y-%m') AS month, country,
         COUNT(*) AS approved_count, SUM(amount) AS approved_total_amount
  FROM Transactions WHERE state = 'approved' GROUP BY DATE_FORMAT(trans_date, '%Y-%m'), country
)
SELECT t.month, t.country, t.trans_count,
       COALESCE(a.approved_count, 0) AS approved_count,
       t.trans_total_amount,
       COALESCE(a.approved_total_amount, 0) AS approved_total_amount
FROM totals t
LEFT JOIN approved a ON a.month = t.month AND a.country <=> t.country;
```

**Why it is correct:** `totals` has one row per group. `approved` has one row per group that has at least one approved row. A LEFT JOIN from `totals` keeps the others and `COALESCE` zeroes them. The join key includes a possibly NULL column, so it must use `<=>`.

**Cost model (reasoned):** two full passes over `Transactions` (one filtered), two aggregations, and a join of two small results. Linear in rows, no per-group rescans. The extra scan and the join are pure overhead compared with doing both measures in the same pass, and the join needs the NULL-safe comparison to be right.

### Approach 3 (optimal): conditional aggregation (`solutions/03_conditional_aggregation.sql`)

The SQL is the assembled query in section 4.

**Why it is correct:** each aggregate sees exactly the rows of its group. The unconditional ones see all of them; the conditional ones see the same rows but add only where `state = 'approved'`. `GROUP BY` puts NULL countries in one group. `ELSE 0` means no group's amount sum can be NULL.

**Cost model (reasoned):** one scan, one hash (or sorted) aggregation whose state is a few numbers per group. The number of groups is small compared with the rows (months × countries), so the aggregation table stays small and in memory. This is also the shape engines pre-aggregate in parallel (section 6c).

**Measured** (`gen.py` data, generated by the bench workflow; the table is filled in automatically, so never type numbers here):

<!-- BENCH:04-monthly-transactions-i -->
<!-- /BENCH -->

### Why the optimal one wins

Approach 3 does the minimum the question asks: one pass over the data and one aggregation, producing all four numbers together, so "all" and "approved" can never disagree about which rows are in the group. Approach 2 reads the table twice and then has to re-align the results on a NULL-able key; approach 1 re-reads it per group. Because every row has to be read to be counted, an index cannot reduce the work for this aggregate: at best it provides an order that avoids a temporary table, so compare both bench tables before assuming it helps.

## 6. At scale

**(a) What breaks first.** *Reasoned, to be checked against the bench table:* approach 1 breaks first (groups × rows), at modest sizes. Approach 2 costs about twice approach 3 and does not fall off a cliff; it just never wins. Approach 3 is linear in rows, with a tiny aggregation state, so it is limited by how fast the table can be read.

**(b) One machine, ~1M–100M rows.**
- This is a full-table aggregation: every row is needed, so there is nothing for an index to *skip*. `indexes.sql` adds a **functional** covering index `((DATE_FORMAT(trans_date,'%Y-%m')), country, state, amount)`: it can replace the temporary table by delivering rows already ordered by the group key (EXPLAIN on a sample showed a streaming group aggregate for approach 3), at the price of a wider structure to scan and maintain. Whether that wins is for the "with indexes" bench to show.
- A plain `trans_date` index helps only when the query adds a date filter, and then only if the filter is a range on the raw column (`trans_date >= '2020-01-01' AND trans_date < '2020-02-01'`), never `DATE_FORMAT(trans_date, '%Y-%m') = '2020-01'`.
- Partition by month (`PARTITION BY RANGE COLUMNS(trans_date)`) once data is large, so closed months are never rescanned (reasoned). That has the same primary-key constraint as any MySQL partitioning: the partition column must be in every unique key.

**(c) Distributed engines, billions of rows. *Reasoned, not measured.***
- *Shuffle:* `SUM` and `COUNT` are decomposable, so each task aggregates its own rows into at most (months × countries) partial rows and the shuffle carries only those. Approach 2 would shuffle and aggregate twice, then join.
- *Skew:* a heavy country (US) puts many rows on one key, but partial aggregation reduces them to one row per task per key before the shuffle, so skew barely matters. This is a case where the cost does not scale with data volume after the first stage.
- *Pruning:* if the data is clustered by `trans_date` (the natural order of arrival), a date filter prunes micro-partitions in Snowflake or files in Parquet-based engines. Without a filter every partition is read, which is correct: the question needs every row.
- *Things to avoid:* a final `ORDER BY` on a huge result (it is small here, so harmless); `COUNT(DISTINCT)` is not needed. If asked for distinct customers per group, partial results must carry sets, and `APPROX_COUNT_DISTINCT` is acceptable for dashboards, not for audited reporting.

**(d) The data-engineering answer.** Months close. Aggregate each new batch and add it to a small `(month, country)` summary instead of rescanning history:

```sql
-- monthly_summary(month, country_key, trans_count, approved_count, trans_total_amount, approved_total_amount).
-- NULL country needs care: a PRIMARY KEY cannot contain NULL, and UNIQUE indexes treat NULLs as distinct, so
-- ON DUPLICATE KEY would insert a NEW NULL row every batch. Store a sentinel (country_key = COALESCE(country, '?'))
-- and map back on read: NULLIF(country_key, '?').

-- Snowflake / ANSI MERGE (UNVERIFIED). EQUAL_NULL is the NULL-safe comparison:
MERGE INTO monthly_summary t
USING (SELECT TO_CHAR(trans_date, 'YYYY-MM') AS month, country,
              COUNT(*) AS n, COUNT_IF(state = 'approved') AS na,
              SUM(amount) AS amt, SUM(IFF(state = 'approved', amount, 0)) AS amt_ok
       FROM transactions_batch             -- only rows not yet applied (watermark on id)
       GROUP BY 1, 2) s
ON t.month = s.month AND EQUAL_NULL(t.country, s.country)
WHEN MATCHED THEN UPDATE SET trans_count = t.trans_count + s.n, approved_count = t.approved_count + s.na,
                             trans_total_amount = t.trans_total_amount + s.amt,
                             approved_total_amount = t.approved_total_amount + s.amt_ok
WHEN NOT MATCHED THEN INSERT (month, country, trans_count, approved_count, trans_total_amount, approved_total_amount)
                      VALUES (s.month, s.country, s.n, s.na, s.amt, s.amt_ok);

-- MySQL equivalent (sentinel key):
INSERT INTO monthly_summary (month, country_key, trans_count, approved_count, trans_total_amount, approved_total_amount)
SELECT DATE_FORMAT(trans_date, '%Y-%m'), COALESCE(country, '?'), COUNT(*), SUM(state = 'approved'),
       SUM(amount), SUM(CASE WHEN state = 'approved' THEN amount ELSE 0 END)
FROM transactions_batch GROUP BY 1, 2
ON DUPLICATE KEY UPDATE trans_count = trans_count + VALUES(trans_count),
                        approved_count = approved_count + VALUES(approved_count),
                        trans_total_amount = trans_total_amount + VALUES(trans_total_amount),
                        approved_total_amount = approved_total_amount + VALUES(approved_total_amount);
```

Caveats interviewers probe. *Idempotency:* a batch applied twice double-counts, so apply by watermark and make re-runs no-ops. *State changes:* a transaction that goes from `declined` to `approved` (or is refunded) is not an insert, so the delta needs a −1/+1 on the old and new state: a change feed with before and after images. *Late data:* a transaction dated last month lands in a closed month; decide whether closed months are mutable.

## 7. Edge cases

Each "breaks" claim below is checked by execution: `mistakes/*.sql` are the tempting wrong queries, and the harness asserts each one fails every dataset it names.

| Case | Dataset | Wrong queries it catches (`mistakes/`) |
|---|---|---|
| Group with no approved row: approved columns are 0 | `tests/edge_typical.sql`, `tests/edge_no_approved.sql` | `case_without_else` (NULL), `where_approved_only` (group disappears), `count_instead_of_sum` |
| Approved transaction with amount 0 (counted as approved, adds nothing) | `tests/edge_typical.sql` | none: a correct reference point for count vs amount |
| NULL country forms its own group; NULL rows in two months are two groups | `tests/edge_null_country.sql` | `count_country_column` (`COUNT(country)` reports 0), `join_on_plain_equality` (the group never matches its approved counterpart) |
| Same calendar month in two years (Jan 2019 vs Jan 2020) | `tests/edge_month_boundaries.sql` | `month_without_year` (merges them) |
| First and last day of a month, a year boundary, a leap day | `tests/edge_month_boundaries.sql` | none in `solutions/`; a hand-written range or `LAST_DAY` shortcut would be the thing to check |
| `'YYYY-MM'` padding: January is `2019-01` | every dataset | `unpadded_month_label` (`2019-1`) |
| Two identical transactions (differing only by `id`) | `tests/edge_no_approved.sql` | none: both count |
| `Transactions` empty | `tests/edge_empty.sql` | none: a `GROUP BY` query returns no rows |

No approach in `solutions/` is broken by any of these. Approach 1 is slow, not wrong.

## 8. Interviewer follow-ups

1. **"Add a third state, `chargeback`."** The conditional-aggregation form just gets two more columns. The two-pass form needs a third join. This is why conditional aggregation scales with the number of measures and joins do not.
2. **"Show months with zero transactions too."** There is nothing to group, so you need a scaffold: a calendar (or generated months) `CROSS JOIN` the countries, then LEFT JOIN the aggregate. The grain becomes the full grid. Same idea as `09-count-salary-categories` and `30-calculate-a-rolling-average-of-total-revenue`.
3. **"Report NULL country as 'Unknown'."** `COALESCE(country, 'Unknown')` in both the SELECT and the GROUP BY. Point out the collision risk if a real country is literally named 'Unknown'.
4. **"Filter to one month."** Filter on the raw column with a half-open range, then group. Do not wrap the column in `DATE_FORMAT` in the `WHERE`: it hides the column from an index and from partition pruning.
5. **"What changes for 10 billion rows?"** Nothing in the SQL. The aggregation state is tiny (groups, not rows), so the cost is reading the table; push a date filter to prune, or serve it from the incremental summary in section 6d.

## 9. Snowflake notes (UNVERIFIED)

`snowflake.sql` keeps the shape of approach 3. What changes:

- `TO_CHAR(trans_date, 'YYYY-MM')` replaces `DATE_FORMAT`; `COUNT_IF(state = 'approved')` replaces `SUM(state = 'approved')` (in Snowflake a boolean cannot be summed directly); `IFF(cond, a, b)` is the idiomatic `CASE`.
- Snowflake allows `GROUP BY ALL` or positional grouping; the explicit form is kept for portability.
- NULL grouping is the same as MySQL: all NULL countries form one group. `MERGE` and `JOIN` comparisons are not, so a join on `country` needs `EQUAL_NULL` / `IS NOT DISTINCT FROM` (the MySQL `<=>`).
- No secondary indexes, so `indexes.sql` has no equivalent. Pruning replaces it: if `trans_date` is the clustering order, a date range filter reads only the matching micro-partitions; the unfiltered aggregate reads every partition but only four columns.
- `SUM(amount)` on an integer column returns a `NUMBER(38,0)`, so it will not overflow like a 32-bit integer sum in some other engines.
- Unquoted identifiers are upper-cased: `MONTH`, `COUNTRY`, `TRANS_COUNT` come back in upper case.

## 10. Pattern links

Same pattern (conditional aggregation, several measures from one pass):
- `08-odd-and-even-transactions`, `10-find-drivers-with-improved-fuel-efficiency`, `11-analyze-subscription-conversion`: the pivot form (one conditional aggregate per output column).
- `24-immediate-food-delivery-ii`: a conditional share over a derived subset.
- `02-confirmation-rate`: a ratio of a conditional count to a total, over the same rows.
- `05-find-loyal-customers`, `06-find-golden-hour-customers`: the same aggregates used in `HAVING`.
- `07-trips-and-users`: a conditional ratio per day, after a join that filters.

Builds on it:
- `09-count-salary-categories`: when a group may have no rows, a scaffold is needed to show it.
