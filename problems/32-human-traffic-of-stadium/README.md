# 32 · Human Traffic of Stadium

## 1. Problem & trigger phrases

Original: [Human Traffic of Stadium](https://leetcode.com/problems/human-traffic-of-stadium/) (LeetCode 601, hard). Read the statement there; this guide only restates the spec in its own words.

**Spec (own words):** call a day *busy* if at least 100 people came. Among busy days, find maximal stretches whose `id`s are consecutive integers. Return every row (all three columns) of every stretch that is 3 or more rows long, sorted by `visit_date`.

| Trigger phrase | What it forces in SQL |
|---|---|
| "three or more rows with consecutive id's" | A *gaps-and-islands* problem on an integer key. Consecutive integers have a constant `id - ROW_NUMBER()`, so that difference labels each island. The key is `id`, not `visit_date`: a skipped date between consecutive ids does not split a run. |
| "people is greater than or equal to 100" | A row filter that must run **before** the rows are numbered. Numbering all rows and filtering afterwards makes the whole table one island. `>=`, not `>`: exactly 100 is busy. |
| "display the records" | The output grain is the input row, not the island. You need the island's size on every row, which is a window `COUNT(*) OVER (PARTITION BY island)` (or a GROUP BY plus a join back). Returning only the row where a run starts is the classic wrong answer. |

## 2. Schema & grain

| Table | One row means | Keys that matter here |
|---|---|---|
| `Stadium` | one visit day | `id` (unique in practice, no constraint, increases with `visit_date`), `visit_date` (unique), `people` |

**Output grain:** one row per qualifying `Stadium` row, the same columns as the input. It is a subset of the table, so the row count can never exceed `SELECT COUNT(*) FROM Stadium WHERE people >= 100`.

**Where the grain changes:** it changes *temporarily*. The test "is this row's run at least 3 long" is a property of the island, not of the row. So the query has to go up to island grain (to measure each island) and then back down to row grain (to return the rows). That round trip is the whole difficulty:

- With a **window** (approach 3), you never leave row grain. `COUNT(*) OVER (PARTITION BY island)` puts the island size on every row.
- With **GROUP BY island** you get one row per island and must join back to the rows to "display the records".
- The brute force (approach 1) never builds islands at all. It asks a local question ("am I part of some triple?"), and the answer for a row inside a run of 5 comes from several triples, hence the `DISTINCT`.

## 3. Hint ladder

<details><summary>Hint 1</summary>

Pattern: **gaps and islands** on an integer key. Rows belong together when their ids have no gaps between them.

</details>

<details><summary>Hint 2</summary>

Shape: (1) keep only the busy days. (2) Give every busy row a label that is the same for all rows of one unbroken id run and different across runs. (3) Measure each label's size while keeping the rows. (4) Keep rows whose label has size 3 or more, then sort by date.

</details>

<details><summary>Hint 3</summary>

Key trick: after filtering, `id - ROW_NUMBER() OVER (ORDER BY id)` is constant inside a run of consecutive ids (in MySQL, write `CAST(ROW_NUMBER() … AS SIGNED)`: the row number is unsigned). Each id gap makes `id` jump by more than `ROW_NUMBER()` does, so the difference steps up. Then `COUNT(*) OVER (PARTITION BY that_difference)` gives every row its island size without a join.

</details>

## 4. Decomposition

Translate each phrase into one step. Notice that "three or more" is a statement about a *group of rows*, while "display the records" asks for *rows*. When you see that pair of phrases, plan to compute a group property and attach it to each row.

1. **`busy`: `WHERE people >= 100 AND id IS NOT NULL`.**
   *Why a filter here, first:* the quiet days are what create the gaps. If you number rows before removing them, the quiet days get numbers too, the busy rows on either side of them look consecutive, and no gap is ever detected. A row with a NULL id has no position in "consecutive ids", so it goes too (otherwise all NULL-id rows share one NULL label in step 3 and look like an island).
2. **`busy`, same CTE: `island = id - CAST(ROW_NUMBER() OVER (ORDER BY id) AS SIGNED)`.**
   *Why a window here:* "consecutive" is about order, and only a window can see a row's position among the other busy rows. The order key is `id`, because the wording says consecutive *ids*. Numbering by `visit_date` would also give the right *order* here, but the island label must subtract a number from `id`, not from a date. *Why the `CAST`:* MySQL returns `ROW_NUMBER()` as `BIGINT UNSIGNED`, so `id - ROW_NUMBER()` is unsigned arithmetic. Whenever `id` is smaller than its row number (ids starting at 0, negative ids), MySQL raises *BIGINT UNSIGNED value is out of range* instead of returning a negative label. LeetCode's ids start at 1, so the bare subtraction passes there and fails on the first table that doesn't.
3. **`sized`: `COUNT(*) OVER (PARTITION BY island)`.**
   *Why a window and not GROUP BY:* the output is the rows themselves. A partition-only window counts the island and keeps every row, so no join back is needed.
4. **Final: `WHERE island_size >= 3 ORDER BY visit_date`.**
   *Why a filter on the window result:* window values exist only after the `SELECT` that computes them, so the size test has to go in the next query level. MySQL has no `QUALIFY`.

```sql
WITH busy AS (                                   -- steps 1 + 2: filter, then label islands
  SELECT id, visit_date, people,
         id - CAST(ROW_NUMBER() OVER (ORDER BY id) AS SIGNED) AS island
  FROM Stadium
  WHERE people >= 100 AND id IS NOT NULL
),
sized AS (                                       -- step 3: island size on every row
  SELECT id, visit_date, people,
         COUNT(*) OVER (PARTITION BY island) AS island_size
  FROM busy
)
SELECT id, visit_date, people                    -- step 4: keep big islands, row grain
FROM sized
WHERE island_size >= 3
ORDER BY visit_date;
```

Worked example of the label, using `tests/edge_typical.sql`: the busy ids are 2, 3, 5, 6, 7, 8, 10, 11. Their row numbers are 1–8, so `id - rn` is 1, 1, 2, 2, 2, 2, 3, 3. That gives three islands, of sizes 2, 4 and 2, and only the four rows labelled 2 come back. The label values mean nothing on their own; only equality between labels matters.

## 5. Approaches: brute force → optimal

### Approach 1: triple self-join (`solutions/01_triple_self_join.sql`)

```sql
SELECT DISTINCT s1.id, s1.visit_date, s1.people
FROM Stadium s1
JOIN Stadium s2 ON s2.people >= 100
JOIN Stadium s3 ON s3.people >= 100
WHERE s1.people >= 100
  AND (   (s2.id = s1.id + 1 AND s3.id = s1.id + 2)   -- s1 starts the triple
       OR (s2.id = s1.id - 1 AND s3.id = s1.id + 1)   -- s1 is in the middle
       OR (s2.id = s1.id - 2 AND s3.id = s1.id - 1))  -- s1 ends the triple
ORDER BY s1.visit_date;
```

**Why it is correct:** a row is in a run of length ≥ 3 exactly when it is the first, middle or last member of some three consecutive busy ids. The three OR branches cover those three positions. A row inside a longer run matches several triples, and `DISTINCT` collapses them. This is the most common first answer, because it spells "three consecutive" out literally.

**Cost model (reasoned from EXPLAIN):** the join conditions are an OR of different equalities, so MySQL has no single equi-join key. Without an index, EXPLAIN shows `Inner hash join (no condition)` twice: a cartesian product of busy × busy, filtered, then × busy again, filtered. That is cubic in the number of busy rows before the filters cut it down, plus a deduplicating temporary table and a final sort. With `indexes.sql` (`PRIMARY KEY (id)`), EXPLAIN switches to `Index range scan … (re-planned for each iteration)`: each of `s2` and `s3` becomes a handful of primary-key probes per `s1` row, which is close to linear. The approach is bad because of the OR, not because it uses a self-join. It also hard-codes the threshold: a run of 5 would need five copies of the table.

### Approach 2: LAG/LEAD neighbours (`solutions/02_lag_lead_neighbours.sql`)

```sql
WITH busy AS (
  SELECT id, visit_date, people,
         LAG(id, 2)  OVER w AS prev2, LAG(id, 1)  OVER w AS prev1,
         LEAD(id, 1) OVER w AS next1, LEAD(id, 2) OVER w AS next2
  FROM Stadium
  WHERE people >= 100
  WINDOW w AS (ORDER BY id)
)
SELECT id, visit_date, people
FROM busy
WHERE (next1 = id + 1 AND next2 = id + 2)
   OR (prev1 = id - 1 AND next1 = id + 1)
   OR (prev2 = id - 2 AND prev1 = id - 1)
ORDER BY visit_date;
```

**Why it is correct:** it is approach 1 with the self-joins replaced by window lookups. Over the filtered rows, `LAG`/`LEAD` return the neighbouring *busy* ids, and the `= id ± k` checks confirm those neighbours are consecutive integers, not just the next busy row. At the edges of the table `LAG`/`LEAD` return NULL, the comparison is unknown, and that branch is simply false.

**Cost model (reasoned from EXPLAIN):** one scan, one sort by `id`, one window pass that buffers two rows ahead, a filter, and the final sort by date. That is as cheap as approach 3, or cheaper (see below). Its weakness is the shape: the threshold is baked into the code. "At least k" needs 2(k−1) window columns and k OR branches, and it is easy to get one wrong.

### Approach 3 (optimal): `id - ROW_NUMBER()` islands (`solutions/03_id_minus_row_number.sql`)

The SQL is the assembled query in section 4.

**Why it is correct:** among the busy rows sorted by `id`, `ROW_NUMBER()` goes up by exactly 1 per row. `id` goes up by exactly 1 inside a run and by more than 1 across a gap. So `id - ROW_NUMBER()` stays constant inside a run and strictly increases at each gap. That gives one label per maximal run, and `COUNT(*)` over that label is the run length.

**Cost model (reasoned from EXPLAIN):** one scan with the filter, a sort by `id` for `ROW_NUMBER()`, a materialised CTE, a second sort by `island` for the partitioned `COUNT`, and the final sort by date. The second sort is over input that is already in `island` order (the label never decreases with `id`), so it is cheap, but MySQL still performs it. MySQL also does not use the primary key to skip the first sort, even with `indexes.sql`. On one machine, approach 2 can therefore measure as fast or faster: compare the rows below.

**Measured** (`gen.py` data, generated by the bench workflow; the table is filled in automatically, so never type numbers here):

<!-- BENCH:32-human-traffic-of-stadium -->
_Measured 2026-11-04 by the bench workflow: MySQL 8.0.46, INTEL(R) XEON(R) PLATINUM 8573C, 2 vCPU. Median of 3 runs after 1 warm-up; each statement capped at 60 s. Sizes are main-table rows from `gen.py`. Raw numbers and EXPLAIN ANALYZE: `bench/results/32-human-traffic-of-stadium.json`._

**Without indexes**

| Solution | 1,000 rows | 100,000 rows | 1,000,000 rows | × slower than optimal @ 1,000,000 |
|---|---:|---:|---:|---:|
| `01_triple_self_join` | 186 ms | timeout >60s | timeout >60s † | > 12× |
| `02_lag_lead_neighbours` | 4.58 ms | 425 ms | 10.9 s | 2.1× |
| `03_id_minus_row_number` (optimal) | 3.9 ms | 361 ms | 5.06 s | 1.0× |

† not run at this size: it already timed out at a smaller size.

**With `indexes.sql`**

| Solution | 1,000 rows | 100,000 rows | 1,000,000 rows | × slower than optimal @ 1,000,000 |
|---|---:|---:|---:|---:|
| `01_triple_self_join` | 9.88 ms | 950 ms | 13.2 s | 2.7× |
| `02_lag_lead_neighbours` | 4.38 ms | 399 ms | 10.7 s | 2.2× |
| `03_id_minus_row_number` (optimal) | 3.8 ms | 344 ms | 4.85 s | 1.0× |

> GitHub-hosted runners are shared, noisy VMs: compare the ratios between rows, not the absolute times.
<!-- /BENCH -->

### Why the optimal one wins

Approach 3 is the only one whose cost and code do not depend on the threshold. "At least 3" and "at least 30" are the same query with a different constant, and the island label is reusable for follow-ups (run start, run end, longest run). Approach 2 is close at 100K rows (425 ms vs 361 ms) but falls behind at 1M (10.9 s vs 5.06 s, 2.1× slower): its four LAG/LEAD columns need a look-ahead buffer, while approach 3's `ROW_NUMBER` streams. Approach 1 is the one to avoid: without an index its OR-join is a cartesian product, and with an index it is fast only because the planner re-plans the probe for every row.

## 6. At scale

**(a) What breaks first.** *Reasoned, then checked by the bench table:* approach 1 without `indexes.sql` goes first, by a wide margin, because the hash join has no key and builds a cross product. Approaches 2 and 3 are bounded by sorting the busy rows. They degrade when the sort buffer (`sort_buffer_size`) and the materialised CTEs stop fitting in memory and spill to disk.

**(b) One machine, ~1M–100M rows.**
- `indexes.sql` makes `id` the primary key. InnoDB then stores rows in `id` order, and approach 1's probes become primary-key lookups. MySQL 8.0 still sorts for the window functions (EXPLAIN shows `Sort: Stadium.id` with or without the key), so the gain for approaches 2 and 3 is limited to locality.
- An index on `people` does not help: `people >= 100` usually keeps a large share of the table, so a full scan beats an index range scan.
- The final `ORDER BY visit_date` is a second full sort of the result. Because `visit_date` increases with `id`, `ORDER BY id` returns the same order. On a table with `id` as the clustered key, an engine that tracks sort order could then skip that sort (reasoned; MySQL still sorts the materialised CTE).
- Rewriting approach 1 with `UNION` of three equi-joins (one per position) instead of one OR gives the hash join a key in each branch. It becomes linear without an index, but it is still a fixed-k query.

**(c) Distributed engines, billions of rows. *Reasoned, not measured.***
- *The global window is the problem.* `ROW_NUMBER() OVER (ORDER BY id)` has no `PARTITION BY`, so a Spark-style engine moves every busy row to **one** task to number them. That is a single-node bottleneck no matter how big the cluster is. Snowflake has the same issue: an unpartitioned window runs on one worker.
- *Fix: partition by a coarse bucket and stitch the seams.* Because consecutiveness is purely on `id`, you can split the id space into ranges (`FLOOR(id / 1e6)`), compute islands within each range in parallel, and then merge islands that touch across a boundary. The merge step only looks at the first and last island of each range, which is a tiny table. Approach 2's local lookups (two rows each way) partition even more easily: give each bucket two overlap rows from its neighbours.
- *Pruning:* in Snowflake, a table loaded in date order is naturally clustered on `visit_date` and `id`. A bounded version of the question ("last 90 days") prunes to a few micro-partitions. The unbounded "whole history" version cannot prune.
- *No approximation applies:* the answer is a set of rows, not a statistic, so approximate functions have no role.

**(d) The data-engineering answer.** Visit days arrive in id order, so islands only change at the tail: a new day can extend the last island, start a new one, or do nothing (if quiet). Keep a small `stadium_islands(island_start_id, island_end_id, size)` table and update only the open island on each load:

```sql
-- New rows arrive in stadium_batch with ids greater than everything already applied (watermark).
-- Snowflake / ANSI MERGE (UNVERIFIED): recompute islands over the open tail only.
MERGE INTO stadium_islands t
USING (
  WITH tail AS (                                      -- the last open island plus the new batch
    SELECT id FROM Stadium
    WHERE id >= (SELECT MAX(island_start_id) FROM stadium_islands) AND people >= 100
    UNION ALL
    SELECT id FROM stadium_batch WHERE people >= 100
  ), lbl AS (
    SELECT id, id - CAST(ROW_NUMBER() OVER (ORDER BY id) AS SIGNED) AS island FROM tail
  )
  SELECT MIN(id) AS island_start_id, MAX(id) AS island_end_id, COUNT(*) AS size
  FROM lbl GROUP BY island
) s
ON t.island_start_id = s.island_start_id
WHEN MATCHED THEN UPDATE SET island_end_id = s.island_end_id, size = s.size
WHEN NOT MATCHED THEN INSERT (island_start_id, island_end_id, size)
                      VALUES (s.island_start_id, s.island_end_id, s.size);

-- The question then becomes a range join from a tiny table:
SELECT st.id, st.visit_date, st.people
FROM stadium_islands i
JOIN Stadium st ON st.id BETWEEN i.island_start_id AND i.island_end_id
WHERE i.size >= 3
ORDER BY st.visit_date;
```

Caveats that interviewers probe. *Late or corrected rows*: a correction to an old day's `people` can split or merge islands in the middle of history, so the "only the tail changes" assumption breaks. Handle it by recomputing islands for the affected id range (the islands that touch the corrected id). *Idempotency*: re-applying a batch is harmless here, because the tail is recomputed from the base table, but only if the batch rows are inserted into `Stadium` exactly once.

## 7. Edge cases

Each "breaks" claim below is checked by execution: `mistakes/*.sql` are the tempting wrong queries, and the harness asserts that each one fails every dataset it names (`harness/test_mistakes.py`).

| Case | Dataset | Wrong queries it catches (`mistakes/`) |
|---|---|---|
| Runs of length 2, 4, 2; middle and last rows of the long run must appear | `tests/edge_typical.sql` | `start_of_triple_only`, `middle_row_only`, `islands_before_filter` |
| Exactly 100 people (busy) vs 99 (not); a run of exactly 3 | `tests/edge_boundary_100.sql` | `strictly_more_than_100`, `start_of_triple_only`, `middle_row_only`, `islands_before_filter` |
| Consecutive ids with skipped dates (qualifies); consecutive dates across a missing id (does not) | `tests/edge_id_vs_date_gaps.sql` | `islands_on_visit_date`, `positional_neighbours` (treats "next busy row" as "next id") |
| Busy days everywhere, but no run reaches 3 | `tests/edge_no_qualifying_run.sql` | none; every approach returns empty |
| `people` is NULL in the middle of a run | `tests/edge_nulls.sql` | `breaker_count_skips_null`: `SUM(people < 100)` skips the NULL, so the unknown day does not split the run. `islands_before_filter` also fails. |
| Rows inserted out of order; runs at the very first and very last row (where LAG/LEAD are NULL) | `tests/edge_ordering.sql` | `start_of_triple_only`, `middle_row_only` |
| Three busy rows with a NULL `id`, plus a real run of 3 | `tests/edge_null_id.sql` | `null_ids_form_an_island` (the NULL labels share one partition of size 3). A bare `id - ROW_NUMBER()` *errors* here: the NULLs sort first and take row numbers 1–3, so id 1 gets row number 4. |
| ids start at 0 | `tests/edge_id_starts_at_zero.sql` | A bare `id - ROW_NUMBER()` errors (`0 - 1` in unsigned arithmetic). Not in `mistakes/`: the harness requires a mistake to return a wrong result, not an error. |

No approach in `solutions/` is broken by any of these. Approach 3 originally used a bare `id - ROW_NUMBER()` with no NULL filter and failed both of the last two datasets; that is why it now has the `CAST` and the `id IS NOT NULL` filter. Approach 1 is slow without an index, not wrong.

One trap that is not in `mistakes/`: forgetting `ORDER BY visit_date`. MySQL usually returns window output in `id` order anyway, so no dataset can reliably catch the omission. It is still a wrong answer, because without `ORDER BY` the order is not guaranteed.

## 8. Interviewer follow-ups

1. **"Return one row per qualifying run: start date, end date, length."** Replace step 3 with `GROUP BY island` and `MIN(visit_date), MAX(visit_date), COUNT(*)`, with `HAVING COUNT(*) >= 3`. The grain becomes the island, and no join back is needed because the output *is* the island.
2. **"Consecutive days instead of consecutive ids."** Change the label to `DATE_SUB(visit_date, INTERVAL ROW_NUMBER() OVER (ORDER BY visit_date) DAY)`. Never write `visit_date - ROW_NUMBER()`: MySQL turns the date into the number `20240131` and the subtraction breaks at every month boundary. See `33-find-users-with-persistent-behavior-patterns`.
3. **"What if ids can repeat or have gaps by design?"** Then id adjacency is the wrong definition, and you number the busy rows *and* all rows by date. The robust label is `ROW_NUMBER() OVER (ORDER BY d) - ROW_NUMBER() OVER (PARTITION BY is_busy ORDER BY d)` over **all** rows: the "difference of two row numbers" form, which does not need integer keys at all.
4. **"Only the longest run."** Group to island grain, then `ORDER BY COUNT(*) DESC LIMIT 1`, after deciding a tie rule (earliest run first is the usual choice). Same move as in problem 33.
5. **"Why not LAG/LEAD?"** Approach 2 is fine for a fixed small threshold, and on MySQL it may even be a little faster (one sort fewer). The trade-off is generality: it does not extend to "at least k" or to run-level outputs without growing the query.

## 9. Snowflake notes (UNVERIFIED)

`snowflake.sql` keeps the shape of approach 3. What changes, and why:

- `QUALIFY COUNT(*) OVER (PARTITION BY island) >= 3` filters on the window result in the same `SELECT`, so the second CTE disappears. The nested window still needs the island label from the first level, because a window function cannot be nested inside another window's `PARTITION BY`.
- `CONDITIONAL_TRUE_EVENT(is_gap) OVER (ORDER BY id)` can produce island labels as a running count of gaps, where `is_gap = id <> LAG(id) OVER (ORDER BY id) + 1` is computed one level down (a window function cannot be nested inside another window's argument). It reads naturally but is Snowflake-only. The `id - ROW_NUMBER()` form is portable and is what interviewers expect.
- Both windows are unpartitioned. In Snowflake that runs on a single worker, so the warehouse size barely matters for this query (section 6c).
- `ORDER BY visit_date` at the end is a global sort. If the consumer does not need order, drop it.

## 10. Pattern links

Same pattern (gaps and islands):
- `31-consecutive-numbers`: the easier version. Fixed run length, LAG/LEAD is enough, and the output is the value rather than the rows.
- `33-find-users-with-persistent-behavior-patterns`: islands on calendar dates (`date - ROW_NUMBER() DAYS`) per partition, plus "keep the longest island per user".

Related:
- `26-find-consistently-improving-employees`: LAG-based checks against a neighbour, the approach 2 style.
- `38-find-students-with-study-spiral-pattern`: a sequence check over ordered rows where position (`ROW_NUMBER`) drives the logic.
