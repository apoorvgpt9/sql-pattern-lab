# 31 · Consecutive Numbers

## 1. Problem & trigger phrases

Original: [Consecutive Numbers](https://leetcode.com/problems/consecutive-numbers/) (LeetCode 180, medium). Read the statement there; this guide only restates the spec in its own words.

**Spec (own words):** a log table has one `num` value per row, in `id` order. Return every distinct value that occurs in at least three rows in a row. Each qualifying value is listed once, in any order.

| Trigger phrase | What it forces in SQL |
|---|---|
| "at least three times consecutively" | A property of a *run* of adjacent rows, not of a value's total count. Either look at fixed neighbours (`LEAD(num, 1)` and `LEAD(num, 2)`, or a three-way self-join) or label each run and measure its length (gaps-and-islands: `ROW_NUMBER() - ROW_NUMBER() OVER (PARTITION BY num)`). "At least" makes the run length `>= 3`, not `= 3`. |
| "(result is a set of numbers)" | `DISTINCT`. A run of 5 contains three windows of three, and a number can qualify in several separate runs. All of those must collapse into one output row. |

Also notice: there is no aggregate in the wording. "Appears three times" would be `GROUP BY num HAVING COUNT(*) >= 3`; "three times in a row" is a different question, and that gap is the whole problem.

## 2. Schema & grain

| Table | One row means | Keys that matter here |
|---|---|---|
| `Logs` | one log entry | `id` (PK, defines the order), `num` (compared as text) |

**Output grain:** one row per distinct qualifying `num`.

**Where the grain changes (two levels):**
1. *Rows → runs:* consecutive equal values form one run. Neighbour access (`LEAD`) works at row grain; islands collapse each run into one row with a length.
2. *Runs → distinct numbers:* a number can have many qualifying runs, and a long run can contain many qualifying triples. `DISTINCT` is the second grain change. Forgetting it is the most common bug (`mistakes/no_distinct.sql`).

## Assumptions

`confidence` is `high`. The spec's note says ids are described as auto-increment, and that it is "safer to treat consecutive as adjacent in id order". Our interpretation, tested:

1. **"Consecutive" means adjacent in id order**, not "ids differ by 1". If rows were deleted and ids have holes, three neighbouring rows with equal `num` still count. All three solutions find the next row by order (`MIN(id) > …`, `LEAD`, `ROW_NUMBER`), not by `id + 1`. Tested in `tests/edge_id_gaps.sql`; `mistakes/id_plus_one_join.sql` shows the textbook `id + 1` join fails it. With gap-free ids, which is what the spec describes, both readings coincide.
2. **`num` is compared as a string** (it is a `VARCHAR`), with MySQL's default case-insensitive collation. The datasets use values where that does not matter.
3. **No NULLs.** The spec says nulls are not a case, so they are not tested. They would make the approaches disagree: in a quick manual trial with three NULL rows in a row, approach 3 (islands) reported a NULL row, because `PARTITION BY` and `GROUP BY` treat NULLs as equal, while approaches 1 and 2 returned nothing, because `NULL = NULL` is not true. Decide explicitly if your data can contain them.

## 3. Hint ladder

<details><summary>Hint 1</summary>

Pattern: **gaps and islands** (runs of equal values), or its fixed-length shortcut, **neighbour comparison with `LEAD`**. The unit is a run, not a value.

</details>

<details><summary>Hint 2</summary>

Shape: (1) put the rows in id order and give each row a way to know its neighbours or its run. (2) Keep the rows that start, or belong to, a run of at least three equal values. (3) Reduce to the distinct numbers.

</details>

<details><summary>Hint 3</summary>

Key trick: number all rows by `id`, number the rows of each `num` by `id`, and subtract. Inside one run of equal values both counters rise by 1 per row, so the difference is constant; a later run of the same value has a different difference. `GROUP BY num, difference HAVING COUNT(*) >= 3`, then `SELECT DISTINCT num`. For a fixed length of 3, `LEAD(num, 1)` and `LEAD(num, 2)` equal to `num` is shorter.

</details>

## 4. Decomposition

Read the wording as "runs, filtered by length, reduced to a set".

1. **`numbered`: `ROW_NUMBER() OVER (ORDER BY id) − ROW_NUMBER() OVER (PARTITION BY num ORDER BY id)`.**
   *Why two windows here:* "consecutive" is about position in the whole log, so the first counter runs over all rows in id order. The second counter restarts for each value. They advance together exactly while the value does not change, so the difference labels the run (the "island"). A plain `GROUP BY num` cannot separate two runs of the same value; the difference can.
2. **`runs`: `GROUP BY num, island`, `COUNT(*)`.**
   *Why a GROUP BY here:* this collapses each run to one row and measures its length. This is the grain change from rows to runs.
3. **Filter `run_length >= 3`.**
   *Why a filter here:* "at least three" is a condition on run length. `>=`, not `=`, since longer runs qualify.
4. **`SELECT DISTINCT num`.**
   *Why DISTINCT here:* the spec asks for a set. A number with two qualifying runs would otherwise appear twice.

Assembled:

```sql
WITH numbered AS (                                                   -- step 1
  SELECT num,
         ROW_NUMBER() OVER (ORDER BY id)
         - ROW_NUMBER() OVER (PARTITION BY num ORDER BY id) AS island
  FROM Logs
),
runs AS (                                                            -- step 2
  SELECT num, island, COUNT(*) AS run_length
  FROM numbered
  GROUP BY num, island
)
SELECT DISTINCT num AS ConsecutiveNums                               -- step 4
FROM runs
WHERE run_length >= 3;                                               -- step 3
```

Self-check before you submit: test a run of 5 (one output row, not three), a number with two separate runs (one output row), and a number that appears three times but never in a row (no output).

## 5. Approaches: brute force → optimal

### Approach 1: join each row to its next two rows by "next id" (`solutions/01_next_id_self_join.sql`)

```sql
SELECT DISTINCT l1.num AS ConsecutiveNums
FROM Logs l1
JOIN Logs l2 ON l2.id = (SELECT MIN(x.id) FROM Logs x WHERE x.id > l1.id)
JOIN Logs l3 ON l3.id = (SELECT MIN(x.id) FROM Logs x WHERE x.id > l2.id)
WHERE l1.num = l2.num AND l2.num = l3.num;
```

**Why it is correct:** for each row, the subquery finds the next existing id, which is the next row in id order whether or not ids have gaps. The same step is repeated for the third row. When all three values are equal, `l1` starts a run of three. `DISTINCT` collapses repeats.

**Cost model (reasoned):** per row, two dependent subqueries that look for the smallest id above the current one. In `EXPLAIN`, MySQL shows each of them as an index range scan with an `Aggregate: min(...)` on top and a filter, re-planned for every row, rather than a single index dive. That means each lookup may read a long stretch of the table, which makes the whole query roughly quadratic in the number of rows. It is the first to hit the bench's 60-second cap. The textbook `id + 1` join would be linear but is wrong on gaps (`mistakes/id_plus_one_join.sql`).

### Approach 2: `LEAD` twice (`solutions/02_lead_two_ahead.sql`)

```sql
SELECT DISTINCT num AS ConsecutiveNums
FROM (
  SELECT num, LEAD(num, 1) OVER w AS next_num, LEAD(num, 2) OVER w AS next_next_num
  FROM Logs
  WINDOW w AS (ORDER BY id)
) t
WHERE num = next_num AND num = next_next_num;
```

**Why it is correct:** in id order, `LEAD(num, 1)` and `LEAD(num, 2)` are the next two rows' values, with or without gaps in the ids. A row where all three agree starts a run of three. The window is named once and reused, so MySQL sorts once. Two separate `OVER (ORDER BY id)` clauses would be treated as two windows and sorted twice.

**Cost model (reasoned):** one ordered pass, but a look-ahead needs MySQL to keep a buffer of rows: the plan shows `Window aggregate with buffering`, and the derived table with three columns is then materialised before the filter. The run length is fixed in the query: for 4 in a row you add another `LEAD`.

### Approach 3 (optimal): islands from a row-number difference (`solutions/03_islands_row_number_diff.sql`)

The SQL is the assembled query in section 4.

**Why it is correct:** within a run of equal values, row *k* of the run has global position *p + k* and position-within-value *q + k*, so the difference *p − q* is the same for the whole run. A different run of the same value starts later in the global order but not later in the per-value order by the same amount, so its difference is different. Grouping by `(num, island)` therefore gives exactly one group per run, and the count is the run length.

**Cost model (reasoned):** two window functions with different orderings (by `id`; by `num, id`), hence two sorts, followed by a small `GROUP BY`. Both are `ROW_NUMBER`s, which MySQL evaluates as a stream without a look-ahead buffer (the plan shows plain `Window aggregate`, not `with buffering`). The run length is a parameter in `HAVING`, not a structure of the query. It also yields run lengths and starting ids as a by-product (`MIN(id)` per island).

**Measured** (`gen.py` data, generated by the bench workflow; the table is filled in automatically, so never type numbers here):

<!-- BENCH:31-consecutive-numbers -->
_Measured 2026-11-04 by the bench workflow: MySQL 8.0.46, AMD EPYC 7763 64-Core Processor, 2 vCPU. Median of 3 runs after 1 warm-up; each statement capped at 60 s. Sizes are main-table rows from `gen.py`. Raw numbers and EXPLAIN ANALYZE: `bench/results/31-consecutive-numbers.json`._

**Without indexes**

| Solution | 1,000 rows | 100,000 rows | 1,000,000 rows | × slower than optimal @ 1,000,000 |
|---|---:|---:|---:|---:|
| `01_next_id_self_join` | 454 ms | timeout >60s | timeout >60s † | > 9× |
| `02_lead_two_ahead` | 3 ms | 233 ms | 10.4 s | 1.6× |
| `03_islands_row_number_diff` (optimal) | 2.38 ms | 224 ms | 6.56 s | 1.0× |

† not run at this size: it already timed out at a smaller size.

> GitHub-hosted runners are shared, noisy VMs: compare the ratios between rows, not the absolute times.
<!-- /BENCH -->

### Why the optimal one wins

Approach 3 labels runs once instead of asking every row about its neighbours: it avoids the quadratic neighbour search of approach 1 and the look-ahead buffer of approach 2, and its structure does not change with the run length. It is also the form that answers the follow-ups (longest run, where a run starts, "exactly N") with a small edit. Approach 2 is shorter and perfectly good for a fixed 3 on small data, and it is the one to write first in an interview if you can state its cost. The ordering of 2 and 3 on large inputs is an empirical question for the bench table; the reasoning above is why 3 is expected to hold up.

## 6. At scale

**(a) What breaks first.** *Reasoned, then checked by the bench table:* approach 1: the dependent "next id" subqueries are the bottleneck and scale roughly with the square of the table size. After that, approach 2's look-ahead buffer and approach 3's two sorts both grow with *n log n*, and a global window sorts the entire log.

**(b) One machine, ~1M–100M rows.**
- The clustered primary key already delivers rows in id order, which is the only order approaches 1 and 2 need. No extra index is recommended: a `(num, id)` index was tried while writing this guide, and the plan still sorted for the per-value window, so `indexes.sql` is intentionally absent.
- Use `LEAD` for a small fixed run length and islands once the length is a parameter or you need run lengths.
- If `num` has few distinct values, the final `DISTINCT` is cheap. The big costs are the window sorts, not the de-duplication.

**(c) Distributed engines, billions of rows. *Reasoned, not measured.***
- *A global order is the bottleneck:* `OVER (ORDER BY id)` without `PARTITION BY` runs on a single partition, in every engine, for both `LEAD` and the first `ROW_NUMBER`. The scalable shape needs a natural partition key (device, session, source) so that `PARTITION BY source ORDER BY id` can run in parallel, one sort per partition. A run that spans partitions is not a concern in that case because it cannot cross a partition.
- *If there is only one global sequence:* split by id range, compute runs per range, and fix up the two boundaries: a run touching a range edge must be merged with its neighbour range's edge run. Only edge rows move between tasks.
- *Alternative run labelling:* flag every row whose value differs from the previous row's (`LAG`), then take a running `SUM` of the flag; equal neighbours share a label. See section 9.
- *Result size:* the output is a handful of numbers, so the final `DISTINCT` and any `ORDER BY` are free. Nothing here needs `COUNT(DISTINCT)` or approximate functions.

**(d) The data-engineering answer.** "Has this number ever appeared three times in a row?" is monotone: once true, it stays true. Keep the answer as a set and a tiny tail state, and process each new batch of log rows incrementally:

```sql
-- qualifying_nums(num PRIMARY KEY); tail_state(last_num, run_len): the run still open at the end of the processed log.
-- For a new batch (ids above the processed maximum), compute islands over [tail row] + batch, where the tail row
-- carries run_len as its weight, then add every number whose run reaches 3.
-- Snowflake / ANSI MERGE (UNVERIFIED):
MERGE INTO qualifying_nums t
USING (SELECT DISTINCT num FROM batch_runs WHERE run_length >= 3) s    -- batch_runs: islands over tail + batch
ON t.num = s.num
WHEN NOT MATCHED THEN INSERT (num) VALUES (s.num);

-- MySQL equivalent (no MERGE):
INSERT IGNORE INTO qualifying_nums (num)
SELECT DISTINCT num FROM batch_runs WHERE run_length >= 3;
```

Caveats: the batch must start from the open tail run, otherwise a run that spans two batches is split and missed. Re-running a batch is harmless, since the insert is idempotent. This only holds if rows are append-only. If a log row can be deleted or edited, the set must be recomputed (a number can stop qualifying).

## 7. Edge cases

Each "breaks" claim below is checked by execution: `mistakes/*.sql` are tempting wrong queries, and the harness asserts that each one fails every dataset it names (`harness/test_mistakes.py`).

| Case | Dataset | Wrong queries it catches (`mistakes/`) |
|---|---|---|
| Runs at the very start and very end of the table; a number that appears 3 times but never in a row | `tests/edge_typical.sql` | `having_count_ge_3`, `span_of_ids`, `run_of_two` ('4' ids 6-7 is a run of two) |
| A run of 5 and a second run of the same number (set semantics); a run of 4 | `tests/edge_long_runs_repeat.sql` | `no_distinct` |
| Pairs and alternations only: nothing qualifies | `tests/edge_runs_of_two.sql` | `run_of_two` |
| A number that occurs 4 times, with its occurrences two positions apart (`x x y x x`) | `tests/edge_not_adjacent.sql` | `having_count_ge_3`, `ends_only`, `span_of_ids` |
| Holes in the ids: three adjacent rows with ids 1, 2, 4 (our assumption: adjacent in order) | `tests/edge_id_gaps.sql` | `id_plus_one_join` |
| Two rows only | `tests/edge_too_few_rows.sql` | none; every approach returns empty |
| Empty table | `tests/edge_empty.sql` | none; every approach returns empty |

NULL values of `num` are outside the spec and not tested (see Assumptions, item 3: the islands approach would differ). No approach in `solutions/` is broken by any tested case.

## 8. Interviewer follow-ups

1. **"Make the run length N."** Islands: change `HAVING COUNT(*) >= N`. `LEAD`: you need `LEAD` for offsets 1 to N−1, which is why it is for fixed small lengths. A self-join needs N−1 joins.
2. **"Return the longest run for each number."** `MAX(run_length)` per `num` over the `runs` CTE, which approach 3 already has.
3. **"Where does each run start and end?"** `MIN(id)` and `MAX(id)` per island. The same CTE, one more aggregate.
4. **"What if ids have gaps, or you can't trust id order?"** Row-number adjacency (as here) handles gaps. If ordering is by a timestamp, order by `(timestamp, id)` and say how ties are broken.
5. **"Why not `GROUP BY num HAVING COUNT(*) >= 3`?"** It counts occurrences, not runs: `x x y x x` has four. `mistakes/having_count_ge_3.sql` demonstrates the failure.

## 9. Snowflake notes (UNVERIFIED)

`snowflake.sql` has the same shape as approach 3. What changes, and why:

- **Run labelling with a flag and a running sum:** an inner query computes `IFF(num = LAG(num) OVER (ORDER BY id), 0, 1) AS new_run`, and an outer query takes `SUM(new_run) OVER (ORDER BY id)` as the run label, so equal neighbours share a label and `GROUP BY` that label gives run lengths. That needs one ordered window but two query levels (window functions cannot be nested). Not run here; it is an alternative to the two `ROW_NUMBER`s.
- **`QUALIFY`** lets the `LEAD` version filter in the same `SELECT` without a derived table: `SELECT DISTINCT num FROM Logs QUALIFY num = LEAD(num, 1) OVER (ORDER BY id) AND num = LEAD(num, 2) OVER (ORDER BY id)`.
- There are no indexes, and a window ordered by `id` over the whole table is a single-partition sort (section 6c). A clustering key on `id` helps only if the table arrives out of order.
- `VARCHAR` equality is case-sensitive by default in Snowflake, where MySQL's default collation is not. For numeric strings that does not matter.
- Unquoted identifiers are upper-cased in the result: `CONSECUTIVENUMS`.

## 10. Pattern links

Same pattern (gaps and islands, runs of adjacent rows):
- `32-human-traffic-of-stadium`: runs of 3+ consecutive ids that meet a condition, the same row-number-difference trick with a filter first.
- `33-find-users-with-persistent-behavior-patterns`: runs of consecutive dates per user, longest run per group.

Same pattern (neighbour access with `LAG`/`LEAD`):
- `25-exchange-seats`: `LEAD`/`LAG` with a fallback for the missing neighbour.
- `26-find-consistently-improving-employees`: `LEAD` over the three most recent rows per group.
- `27-most-common-course-pairs`: `LEAD` to form adjacent pairs, then count them.
