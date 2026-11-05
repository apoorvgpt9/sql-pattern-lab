# 09 · Count Salary Categories

## 1. Problem & trigger phrases

Original: [Count Salary Categories](https://leetcode.com/problems/count-salary-categories/) (LeetCode 1907, medium). Read the statement there; this guide only restates the spec in its own words.

**Spec (own words):** bucket every account by income into three named categories, and report how many accounts fall in each. All three category rows are always present, with 0 for an empty one. The category names are fixed strings.

| Trigger phrase | What it forces in SQL |
|---|---|
| "must contain all three categories" | The output rows are a **fixed list**, not something that can be read off the data. If a group has no accounts, a `GROUP BY` never creates it. Build the list yourself (a 3-row scaffold) and attach the counts to it, or compute three scalar counts and unpivot them. |
| "return 0" | The empty category is a row that exists only in your scaffold. Counting must give 0, not NULL and not 1: `COALESCE(n, 0)` after a LEFT JOIN, or `COUNT(...)` of nothing in a scalar aggregate. |
| "strictly less than / inclusive range" | Boundary arithmetic: Low is `< 20000`, Average is `20000 ≤ x ≤ 50000` (both ends in), High is `> 50000`. Write each bound once and test 19999, 20000, 50000, 50001. |

Not in the wording: a join to another table. There is only `Accounts`. The "other side" of the join is the category list, which you have to invent.

## 2. Schema & grain

| Table | One row means | Columns that matter |
|---|---|---|
| `Accounts` | one account | `income` (the only column read; `account_id` is just what you count) |

**Output grain:** exactly three rows, one per category. Unlike most problems, the output grain does **not** come from any input table: the number of rows is a constant (3), whatever `Accounts` contains, including nothing.

**Where the grain changes:** account grain → category grain, and then a second, separate step to make sure the category grain is *complete*. Aggregating gives you "the categories that occurred"; the spec wants "the categories that exist". Most wrong answers do the first and forget the second.

## Assumptions

Confidence is `high`; the spec is silent on the following, so this guide picks an interpretation and a dataset tests it.

1. **NULL income belongs to no category.** `NULL < 20000`, `NULL BETWEEN …` and `NULL > 50000` are all unknown, so a NULL-income account is counted nowhere, and a NULL does not become a "high earner" by elimination. Tested in `tests/edge_nulls.sql`. (`schema.sql` makes `income` nullable for this reason; the original table has it not null.)
2. **Zero and negative incomes are Low.** They satisfy `income < 20000`. Zero is tested in `tests/edge_boundaries.sql`.
3. **Equal incomes are separate accounts.** The count is of accounts, not of distinct incomes (`tests/edge_typical.sql`).

## 3. Hint ladder

<details><summary>Hint 1</summary>

Pattern: **scaffold + LEFT JOIN** (a "date spine" with categories instead of dates), or equivalently pivot-then-unpivot. The output rows must exist even when the data has nothing for them.

</details>

<details><summary>Hint 2</summary>

Shape: (1) decide which category each account is in, (2) count accounts per category, (3) write down the three category names by hand, (4) attach the counts to those three names, turning "no count" into 0.

</details>

<details><summary>Hint 3</summary>

Key trick: the three names come from a `UNION ALL` of literals, and the counts are attached with a **LEFT JOIN from the scaffold** plus `COALESCE(n, 0)`. Alternatively skip the join: one scalar `SELECT COUNT(CASE …), COUNT(CASE …), COUNT(CASE …) FROM Accounts` always returns exactly one row (zeros on an empty table), and a `UNION ALL` of three `SELECT`s from it turns the columns into rows. Write the bounds as `< 20000`, `BETWEEN 20000 AND 50000`, `> 50000`, with no `ELSE`.

</details>

## 4. Decomposition

Start from the output: three named rows. Ask "where does each row come from?". The names come from the spec, not from the data, which is what makes this problem different.

1. **`counts`: classify each account with a `CASE`.**
   *Why a CASE here:* "Low / Average / High" are labels computed from `income`; the three ranges are mutually exclusive and cover every non-NULL income, so a searched `CASE` assigns exactly one. No `ELSE`: a NULL income should get no label.
2. **`counts`: `GROUP BY` the label, `COUNT(*)`.**
   *Why a GROUP BY here:* "count accounts per category" is account grain → category grain. After this step you have only the categories that occurred.
3. **`scaffold`: `UNION ALL` of the three literal names.**
   *Why a scaffold here:* "must contain all three" means rows with no source data. Rows that no table contains can only come from a constant.
4. **Final: `scaffold LEFT JOIN counts`, `COALESCE(n, 0)`.**
   *Why a LEFT JOIN, and from the scaffold:* the scaffold is the side whose rows must all survive. Any account-derived table on the left, or an inner join, brings back the missing-row bug. *Why COALESCE:* the LEFT JOIN gives NULL for an empty category, and "return 0" asks for 0.

Assembled (this is `solutions/02_group_then_scaffold_join.sql`):

```sql
WITH counts AS (                                   -- steps 1 + 2: account grain -> category grain
  SELECT CASE WHEN income < 20000                 THEN 'Low Salary'
              WHEN income BETWEEN 20000 AND 50000 THEN 'Average Salary'
              WHEN income > 50000                 THEN 'High Salary' END AS category,
         COUNT(*) AS n
  FROM Accounts
  GROUP BY 1
),
scaffold AS (                                      -- step 3: the rows that must exist
  SELECT 'Low Salary' AS category UNION ALL SELECT 'Average Salary' UNION ALL SELECT 'High Salary'
)
SELECT s.category, COALESCE(c.n, 0) AS accounts_count   -- step 4: keep all three, 0 for "no count"
FROM scaffold s LEFT JOIN counts c ON c.category = s.category;
```

Self-check: run it against an empty `Accounts` and against a table where every income is the same. You should still get three rows. Then add an account at exactly 20000 and make sure it lands in Average.

## 5. Approaches: brute force → optimal

### Approach 1: one COUNT per category, UNION ALL (`solutions/01_union_of_three_counts.sql`)

```sql
SELECT 'Low Salary' AS category, COUNT(*) AS accounts_count FROM Accounts WHERE income < 20000
UNION ALL
SELECT 'Average Salary', COUNT(*) FROM Accounts WHERE income BETWEEN 20000 AND 50000
UNION ALL
SELECT 'High Salary', COUNT(*) FROM Accounts WHERE income > 50000;
```

**Why it is correct:** each branch is an aggregate with no `GROUP BY`, and such a query returns exactly one row even over zero input rows (`COUNT(*)` is 0). So the three rows exist by construction, no scaffold needed. The three predicates are exclusive, and the NULL-income accounts match none of them. It is the most natural first attempt because the spec lists three categories.

**Cost model (reasoned):** three scans of `Accounts`, one per branch. The cost is 3 × rows, with no temporary tables and no joins. With the `indexes.sql` index each branch becomes a range read over the (covering) index on `income`, which reads only the entries in that range; together the three branches then read each index entry once. Measured at 1M rows: about 1.4× approach 3 without the index, and the **fastest** of the three with it (about 0.7× approach 3). Each branch is then a covering range scan that only counts entries, with nothing to evaluate per row.

### Approach 2: classify, group, join onto a scaffold (`solutions/02_group_then_scaffold_join.sql`)

The SQL is the assembled query in section 4.

**Why it is correct:** the `CASE` produces exactly one label or NULL per account; the `NULL` label forms its own group, which the scaffold never matches, so NULL-income accounts disappear (the assumption). The scaffold has three rows and each join to `counts` is 1:1, so the output has exactly three rows. Replace the `LEFT JOIN` with `JOIN`, or drop the scaffold, and empty categories vanish (`mistakes/inner_join_to_scaffold.sql`, `mistakes/group_by_only.sql`).

**Cost model (reasoned):** one scan of `Accounts`; the `GROUP BY` has at most four groups (three labels plus NULL), so its temporary table is tiny; the join is between 3 and about 4 rows. The cost is one scan plus an evaluation of the `CASE` per row. It matches approach 3 in scans but needs the aggregation machinery that approach 3 does not. Measured, that machinery is not small: approach 2 is the slowest of the three at 1M rows (about 1.9× approach 3 without the index, 2.6× with it, and slower than approach 1's three scans). In the plan, the scan takes about 0.15 s, and computing the `CASE` label and grouping 1M rows by that string in a temporary table takes another 0.35 s.

### Approach 3 (optimal): scalar pivot, then unpivot (`solutions/03_pivot_then_unpivot.sql`)

```sql
WITH c AS (
  SELECT COUNT(CASE WHEN income < 20000                  THEN 1 END) AS low_n,
         COUNT(CASE WHEN income BETWEEN 20000 AND 50000  THEN 1 END) AS avg_n,
         COUNT(CASE WHEN income > 50000                  THEN 1 END) AS high_n
  FROM Accounts
)
SELECT 'Low Salary' AS category, low_n AS accounts_count FROM c
UNION ALL SELECT 'Average Salary', avg_n  FROM c
UNION ALL SELECT 'High Salary',    high_n FROM c;
```

**Why it is correct:** an aggregate without `GROUP BY` returns exactly one row, with `COUNT` of no rows equal to 0, so `c` always has one row with three non-NULL counts. `COUNT(CASE … THEN 1 END)` counts only the rows whose `CASE` fired, and a NULL income fires none. The final `UNION ALL` turns that one wide row into three narrow rows. No join and no `COALESCE` are needed, because nothing can be missing.

**Cost model (reasoned):** one scan of `Accounts` with three accumulators, no `GROUP BY`, no temporary table, no join. MySQL 8.0 materialises a CTE that is referenced several times once, so the three branches read a one-row table. The plan shows MySQL evaluating the one-row CTE once, before the `UNION ALL` runs. Compared with approach 2, both are a single scan, but approach 3 only increments three counters per row instead of building a string key and probing a temporary table. The bench shows that difference is about 2× at 1M rows, not "close".

**Measured** (`gen.py` data, generated by the bench workflow; the table is filled in automatically, so never type numbers here):

<!-- BENCH:09-count-salary-categories -->
_Measured 2026-11-04 by the bench workflow: MySQL 8.0.46, Intel(R) Xeon(R) Platinum 8370C CPU @ 2.80GHz, 2 vCPU. Median of 3 runs after 1 warm-up; each statement capped at 60 s. Sizes are main-table rows from `gen.py`. Raw numbers and EXPLAIN ANALYZE: `bench/results/09-count-salary-categories.json`._

**Without indexes**

| Solution | 1,000 rows | 100,000 rows | 1,000,000 rows | × slower than optimal @ 1,000,000 |
|---|---:|---:|---:|---:|
| `01_union_of_three_counts` | 868 µs | 35.8 ms | 351 ms | 1.4× |
| `02_group_then_scaffold_join` | 1.06 ms | 47.6 ms | 475 ms | 1.9× |
| `03_pivot_then_unpivot` (optimal) | 713 µs | 21.6 ms | 246 ms | 1.0× |

**With `indexes.sql`**

| Solution | 1,000 rows | 100,000 rows | 1,000,000 rows | × slower than optimal @ 1,000,000 |
|---|---:|---:|---:|---:|
| `01_union_of_three_counts` | 677 µs | 14.3 ms | 135 ms | 0.7× |
| `02_group_then_scaffold_join` | 1.03 ms | 41.4 ms | 518 ms | 2.6× |
| `03_pivot_then_unpivot` (optimal) | 1.21 ms | 20.2 ms | 197 ms | 1.0× |

A ratio below 1.0× means that approach was faster than the one labelled optimal here.

> GitHub-hosted runners are shared, noisy VMs: compare the ratios between rows, not the absolute times.
<!-- /BENCH -->

### Why the optimal one wins

Without an index it is the fastest (approach 1 about 1.4×, approach 2 about 1.9× at 1M rows), because it does the minimum: read each account once, bump one of three counters, and print the counters as rows. The "must contain all three" requirement is satisfied structurally (the scalar aggregate always has one row) instead of by a join that you have to keep correct. With `indexes.sql` the measurement flips. Approach 1 wins, because three covering range scans that only count index entries are cheaper than one scan that evaluates three `CASE` expressions per row. So on MySQL, if an `income` index exists, the "naive" three-query version is the quick one; it is still three passes, which matters once the data no longer fits in memory (reasoned). Approach 2 is the general-purpose pattern: it is the one to reach for when the categories number in the dozens or come from a table, because a hand-written column per category stops scaling. It is also the slowest here.

## 6. At scale

**(a) What breaks first.** *Measured to 1M rows, reasoned beyond:* nothing breaks dramatically, because every approach is linear in rows and every intermediate result has about three rows. What separates them up to 1M is per-row CPU, not I/O: approach 2's string-keyed temporary-table aggregation makes it the slowest, and approach 1's three scans are cheap while the table sits in the buffer pool. Beyond memory (reasoned), approach 1's three passes become three cold reads and it falls behind, unless the `income` index keeps each pass to its own range.

**(b) One machine, ~1M–100M rows.**
- `indexes.sql` adds `Accounts (income)`. InnoDB secondary indexes carry the primary key, so this index covers every query here. Approach 1 reads three disjoint index ranges (the whole index once, in total) and becomes the fastest approach (measured, 1M rows). Approach 3 gains a little, and approach 2 does not gain at all, because their per-row work, not the read, is the cost.
- `income` is the only column read, so a narrow table (or a covering index) is what matters. Nothing here benefits from sorting.
- The bounds are on the raw column, so they are index-friendly. Wrapping `income` in a function (for example `FLOOR(income / 10000)`) would defeat the range scan.
- If the answer is queried often, the real fix is not a faster query but a precomputed one (section 6d).

**(c) Distributed engines, billions of rows. *Reasoned, not measured.***
- *Shuffle:* `COUNT` is decomposable, so each task counts its own partition and only the partial counts move. Approach 3 has no group key at all, so the final step reduces a handful of numbers per task into three. Approach 2 groups by label, which in a Spark-style engine is a shuffle with only three or four distinct keys; partial aggregation makes it cheap, but without it every row would go to one of four reducers (a skew problem by construction).
- *Scans:* in a columnar warehouse only the `income` column is read. Approach 1's three scans read it three times unless the optimiser shares the scan; approach 3 states the single pass explicitly.
- *Pruning:* ranges on `income` could prune partitions only if the data were clustered by income, which is unusual for an accounts table. Do not count on it.
- *Things to avoid:* a global sort, `COUNT(DISTINCT …)` (the question counts rows, not distinct incomes), and anything that moves one row per account across the network just to count it. Approximate functions are never appropriate for a count of three buckets that someone will reconcile.

**(d) The data-engineering answer.** Category counts are cheap to maintain incrementally *if* you handle account changes, because a raise moves an account from one category to another. Keep a three-row table and apply deltas from a change feed:

```sql
-- category_counts(category PRIMARY KEY, accounts_count): seeded once with the three names at 0
-- (the seeded table IS the persistent scaffold).
-- income_changes(account_id, old_income, new_income): old_income NULL for inserts, new_income NULL for deletes.
-- Snowflake / ANSI MERGE (UNVERIFIED):
MERGE INTO category_counts t
USING (
  SELECT category, SUM(delta) AS delta
  FROM (
    SELECT CASE WHEN new_income < 20000 THEN 'Low Salary'
                WHEN new_income BETWEEN 20000 AND 50000 THEN 'Average Salary'
                WHEN new_income > 50000 THEN 'High Salary' END AS category,  1 AS delta FROM income_changes
    UNION ALL
    SELECT CASE WHEN old_income < 20000 THEN 'Low Salary'
                WHEN old_income BETWEEN 20000 AND 50000 THEN 'Average Salary'
                WHEN old_income > 50000 THEN 'High Salary' END AS category, -1 AS delta FROM income_changes
  ) x
  WHERE category IS NOT NULL
  GROUP BY category
) s ON t.category = s.category
WHEN MATCHED THEN UPDATE SET accounts_count = t.accounts_count + s.delta;
-- (no WHEN NOT MATCHED: the scaffold table already has all three rows, so there is nothing to insert)
```

Caveats interviewers probe. *Idempotency*: applying the same change batch twice double-counts, so track applied change ids. *Threshold changes*: if the cut-offs move, the incremental table is wrong for every account near the old and new cut-offs, and the safe move is a full recompute. That is a reason to keep the cut-offs in a small `salary_bands(category, lo, hi)` table (follow-up 1) rather than in code, so the recompute is a join, not a redeploy.

## 7. Edge cases

Each "breaks" claim below is checked by execution: `mistakes/*.sql` are the tempting wrong queries, and the harness asserts that each one fails every dataset it names (`harness/test_mistakes.py`).

| Case | Dataset | Wrong queries it catches (`mistakes/`) |
|---|---|---|
| Incomes exactly at 19999, 20000, 50000, 50001 | `tests/edge_boundaries.sql` | `low_inclusive` (cut-off account counted twice), `average_exclusive` (cut-off accounts counted nowhere) |
| Zero income | `tests/edge_boundaries.sql` | none of these mistakes; a `WHERE income > 0` clean-up would break it |
| A category with no accounts (two at once) | `tests/edge_missing_categories.sql` | `group_by_only` (rows missing), `inner_join_to_scaffold` (rows missing), `count_star_after_left_join` (1 instead of 0) |
| `Accounts` empty | `tests/edge_empty.sql` | `group_by_only` (zero rows), `inner_join_to_scaffold`, `count_star_after_left_join` |
| NULL income | `tests/edge_nulls.sql` | `else_high` (NULL lands in High), `group_by_only` (an extra NULL-category row), plus the three above |
| Two accounts with the same income; every category populated | `tests/edge_typical.sql` | `count_distinct_income` (equal incomes collapse) |

No approach in `solutions/` is broken by any of these.

## 8. Interviewer follow-ups

1. **"The thresholds change every quarter."** Put them in a table `salary_bands(category, lo, hi)` and join on the range: `salary_bands b LEFT JOIN Accounts a ON a.income >= b.lo AND a.income < b.hi`, then `COUNT(a.account_id)`. This is a non-equi join, so it cannot use a hash join: the cost is accounts × bands unless the engine has a range-join optimisation. With three bands that is fine; with hundreds, bucket first (`FLOOR(income / step)`) and join on the bucket.
2. **"Why did you need a scaffold at all? Doesn't `GROUP BY` give me the categories?"** It gives the categories that occur, which is not the same as the categories that exist. Say that sentence; it is the heart of this pattern.
3. **"Add the percentage of accounts per category."** Counts divided by the total, but decide the denominator: all accounts, or only non-NULL incomes? They differ when there are NULLs. Mind MySQL's division (`/` returns extra decimals) and round once, at the end.
4. **"Is `BETWEEN` safe here?"** For integers, yes. For decimals, `BETWEEN 20000 AND 50000` still includes 50000.00 but excludes 50000.01 (which is above 50000 and so High, as intended). The danger is with half-open spec wording on continuous values; write `>= lo AND < hi` there.
5. **"Do it without UNION ALL."** In MySQL 8.0.19+ a table value constructor builds the scaffold: `FROM (VALUES ROW('Low Salary'), ROW('Average Salary'), ROW('High Salary')) AS s(category)`. It is the same scaffold with nicer syntax.

## 9. Snowflake notes (UNVERIFIED)

`snowflake.sql` keeps the shape of approach 3. What changes, and why:

- `COUNT_IF(cond)` replaces `COUNT(CASE WHEN cond THEN 1 END)`. Same result, shorter, and it ignores NULL conditions.
- A `VALUES ('Low Salary'), ('Average Salary'), ('High Salary')` clause is the usual scaffold; Snowflake also has `UNPIVOT`, which turns the three columns of `c` into rows directly, at the price of a column-name-to-label mapping.
- A `GENERATOR` table function is for numeric or date spines; it is not needed for three fixed labels.
- There are no indexes, so `indexes.sql` has no equivalent. A single pass over one column is cheap in a columnar store whichever approach you use. Approach 1's three passes may or may not be merged by the optimiser: look at *bytes scanned* in the query profile.
- Unquoted identifiers are upper-cased: the result columns come back as `CATEGORY` and `ACCOUNTS_COUNT`.

## 10. Pattern links

Same pattern (rows that must exist even though no data backs them; scaffold + LEFT JOIN):
- `01-market-analysis-i`: LEFT JOIN preservation, but there the missing rows (users) exist in a table. Here they exist nowhere.
- `30-calculate-a-rolling-average-of-total-revenue`: the scaffold is a calendar.
- `29-restaurant-growth`: windows over a date series with gaps.

Related (pivot and unpivot):
- `08-odd-and-even-transactions`: pivot by conditional aggregation; approach 3 here is the same device without a `GROUP BY`.
- `10-find-drivers-with-improved-fuel-efficiency`: pivot into two buckets, then compare them.
