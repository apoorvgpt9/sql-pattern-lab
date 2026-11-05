# 28 · Last Person to Fit in the Bus

## 1. Problem & trigger phrases

Original: [Last Person to Fit in the Bus](https://leetcode.com/problems/last-person-to-fit-in-the-bus/) (LeetCode 1204, medium). Read the statement there; this guide only restates the spec in its own words.

**Spec (own words):** people board a bus one at a time in `turn` order. The bus carries at most 1000 kg in total. Return the name of the last person who can board, i.e. the person with the highest turn whose own weight plus everyone before them still adds up to 1000 or less.

| Trigger phrase | What it forces in SQL |
|---|---|
| "weight limit of 1000 kilograms" | A **running total**: for each person, the sum of the weights of everyone up to and including them in turn order. `SUM(weight) OVER (ORDER BY turn)`, or a self-join on `turn <=`. A limit is inclusive: a total of exactly 1000 still fits, so the comparison is `<= 1000`. |
| "last person that can fit" | Keep the rows whose running total is within the limit, then take the one with the largest `turn` (`ORDER BY turn DESC LIMIT 1`). The output is one row and one column. |
| "only one person can board" | Boarding is strictly in turn order and stops at the first person who does not fit. Nobody skips ahead of the overflow person, even if someone later is light enough to fit. This is *not* a knapsack and not "greedy fill". |

Also notice: no `GROUP BY` appears anywhere. The running total keeps one row per person, and only the last step reduces to one row.

## 2. Schema & grain

| Table | One row means | Keys that matter here |
|---|---|---|
| `Queue` | one person waiting | `turn` (boarding order, unique, 1..n), `weight`, `person_name`; `person_id` is only a key |

**Output grain:** one row, one column: the name of one person.

**Where the grain changes:** nowhere until the last step. The running total is a *window* result, so it keeps the input grain (one row per person) and adds a column. Only `ORDER BY turn DESC LIMIT 1` collapses the table to one row. Because weights are positive, the running total never decreases, so "totals within the limit" is a prefix of the queue and "last row of that prefix" is the boundary.

`person_id` does not follow `turn`. Using it as the order is the most common wrong answer (`mistakes/order_by_person_id.sql`).

## Assumptions

`confidence` is `high`. The spec's guarantees are used as follows:

1. **`turn` is unique and runs 1..n.** Approaches 1 and 3 only need `turn` to be a unique order; approach 2 also needs *no gaps*, because it steps with `turn + 1`.
2. **Weights are positive integers** (people). This makes the running total monotone, which is why "last row with total ≤ 1000" equals "last person before the first overflow", and why at most 1000 people can ever board. With zero or negative weights the two readings split (follow-up 3).
3. **The first person always fits** (spec). If the queue is empty, or the first person were over 1000, all three solutions return no row.
4. The capacity (1000) is hard-coded, as in the spec.

## 3. Hint ladder

<details><summary>Hint 1</summary>

Pattern: **running total** (cumulative sum) with a threshold: compute a prefix sum in boarding order, then pick the boundary row.

</details>

<details><summary>Hint 2</summary>

Shape: (1) for every person, the total weight of everyone up to and including them, in turn order. (2) Keep only people whose total is at most 1000. (3) Of those, take the one who boards last.

</details>

<details><summary>Hint 3</summary>

Key trick: `SUM(weight) OVER (ORDER BY turn ROWS UNBOUNDED PRECEDING)` gives the running total. Do not forget `ORDER BY` inside `OVER` (without it every row gets the grand total). Use `<=`, not `<`. Order by `turn`, not `person_id`. Finish with `ORDER BY turn DESC LIMIT 1`. 

</details>

## 4. Decomposition

Read the wording as a process: people arrive in order, weight accumulates, and we want the last person before the limit is passed.

1. **`running`: running total of weight in turn order.**
   *Why a window (or self-join) here:* each person's total depends on everyone before them, so it is neither a per-row value nor a `GROUP BY` result. `GROUP BY` would collapse the people we still need. A window adds the prefix sum to each row.
2. **Keep rows with `total_weight <= 1000`.**
   *Why a filter here:* "weight limit" is a condition on the running total. It is inclusive, and a window result can only be filtered in an outer query (or `QUALIFY` in Snowflake), because `WHERE` is evaluated before windows.
3. **`ORDER BY turn DESC LIMIT 1`.**
   *Why an ORDER BY / LIMIT here:* "last person" is the maximum turn in the surviving prefix. One row, one column.

Assembled:

```sql
SELECT person_name
FROM (
  SELECT person_name, turn,
         SUM(weight) OVER (ORDER BY turn ROWS UNBOUNDED PRECEDING) AS total_weight   -- step 1
  FROM Queue
) t
WHERE total_weight <= 1000                                                           -- step 2
ORDER BY turn DESC                                                                   -- step 3
LIMIT 1;
```

The assembled query computes a total for every person, though only the first dozen or so matter. Approach 2 in section 5 exploits that fact, and section 5 shows when it pays off.

Self-check before you submit: change the capacity to the exact running total of someone in the middle and make sure that person is returned (the inclusive boundary). Then shuffle `person_id` and make sure the answer does not change.

## 5. Approaches: brute force → optimal

### Approach 1: self-join prefix sum (`solutions/01_self_join_prefix_sum.sql`)

```sql
SELECT q1.person_name
FROM Queue q1
JOIN Queue q2 ON q2.turn <= q1.turn
GROUP BY q1.person_id, q1.turn, q1.person_name
HAVING SUM(q2.weight) <= 1000
ORDER BY q1.turn DESC
LIMIT 1;
```

**Why it is correct:** joining each person to everyone with a turn at most theirs lists exactly their prefix; summing it gives the running total. `HAVING` keeps the ones that fit, and the last by turn is the answer. It is the natural pre-window-function formulation.

**Cost model (reasoned):** the join produces about *n²/2* rows (every person with every earlier person), and the join condition is an inequality, so there is no equality key to hash or look up on, and the join degenerates into comparing pairs. It then groups all those rows. The work is quadratic in the length of the queue, however short the boarding part is. Expect it to be the first to hit the 60-second cap in the bench.

### Approach 2 (conditional fast path): simulate the boarding with a recursive CTE (`solutions/02_recursive_boarding.sql`)

```sql
WITH RECURSIVE boarding AS (
  SELECT turn, person_name, weight AS total_weight
  FROM Queue
  WHERE turn = (SELECT MIN(turn) FROM Queue) AND weight <= 1000
  UNION ALL
  SELECT q.turn, q.person_name, b.total_weight + q.weight
  FROM boarding b
  JOIN Queue q ON q.turn = b.turn + 1
  WHERE b.total_weight + q.weight <= 1000
)
SELECT person_name FROM boarding ORDER BY turn DESC LIMIT 1;
```

**Why it is correct:** the anchor row is the first person. Each recursive step adds the person with the next turn *only if* the new total still fits; when it does not, the step produces no row and the recursion ends, which is exactly "stop at the first overflow". The last row produced is the last person who boards. It matches the spec literally, and uses the guarantee that turns have no gaps.

**Cost model:** the number of recursive steps equals the number of people who board, at most 1000 for positive integer weights, so the default `cte_max_recursion_depth` of 1000 is enough (reasoned). With an index on `turn` (see `indexes.sql`) each step is one lookup, so the total work does **not grow with the length of the queue**: measured flat at ~0.65 ms from 1K to 1M rows. Without that index each step has to find `turn + 1` in an unindexed table, and the bench measures it about 2.5× *slower* than approach 3 at 1M rows (3.07 s vs 1.24 s).

### Approach 3 (optimal): window running sum (`solutions/03_window_running_sum.sql`)

The SQL is the assembled query in section 4.

**Why it is correct:** the window adds each person's prefix total in turn order, and since weights are positive the totals only grow, so the rows with `total_weight <= 1000` form a prefix of the queue; its last row (largest turn) is the last person who fits. `ROWS UNBOUNDED PRECEDING` makes the frame explicit, instead of relying on the default `RANGE` frame.

**Cost model:** one ordered pass with a running accumulator, so linear apart from the sort by `turn` (reasoned). The derived table is materialised with a total for every person, and only afterwards is the filter and `LIMIT 1` applied: MySQL does not stop the window early, so the work grows with the queue length even though only the first ~dozen rows matter. Measured: it grows roughly linearly (61 ms at 100K, 0.89 s at 1M without indexes), and it is the fastest approach when `turn` has no index.

**Measured** (`gen.py` data, generated by the bench workflow; the table is filled in automatically, so never type numbers here):

<!-- BENCH:28-last-person-to-fit-in-the-bus -->
_Measured 2026-11-05 by the bench workflow: MySQL 8.0.46, AMD EPYC 9V74 80-Core Processor, 2 vCPU. Median of 3 runs after 1 warm-up; each statement capped at 60 s. Sizes are main-table rows from `gen.py`. Raw numbers and EXPLAIN ANALYZE: `bench/results/28-last-person-to-fit-in-the-bus.json`._

**Without indexes**

| Solution | 1,000 rows | 100,000 rows | 1,000,000 rows | × slower than optimal @ 1,000,000 |
|---|---:|---:|---:|---:|
| `01_self_join_prefix_sum` | 1.01 s | timeout >60s | timeout >60s † | > 67× |
| `02_recursive_boarding` | 2.86 ms | 231 ms | 2.34 s | 2.6× |
| `03_window_running_sum` (optimal) | 946 µs | 61.4 ms | 890 ms | 1.0× |

† not run at this size: it already timed out at a smaller size.

**With `indexes.sql`**

| Solution | 1,000 rows | 100,000 rows | 1,000,000 rows | × slower than optimal @ 1,000,000 |
|---|---:|---:|---:|---:|
| `01_self_join_prefix_sum` | 977 ms | timeout >60s | timeout >60s † | > 70× |
| `02_recursive_boarding` | 490 µs | 494 µs | 551 µs | 0.0× |
| `03_window_running_sum` (optimal) | 903 µs | 56.1 ms | 860 ms | 1.0× |

† not run at this size: it already timed out at a smaller size.

A ratio below 1.0× means that approach was faster than the one labelled optimal here.

> GitHub-hosted runners are shared, noisy VMs: compare the ratios between rows, not the absolute times.
<!-- /BENCH -->

### Why the optimal one wins

On the schema as given (no index on `turn`), the window is the fastest approach: about 2.5× faster than the recursive CTE at 1M rows, because one ordered pass beats a recursion whose every step must find `turn + 1` in an unindexed table. It also needs no guarantee beyond unique turns and positive weights. The recursive CTE is the better answer only when you can add the `turn` index: then it reads just the people who board and stays flat at under a millisecond while the window still pays for the whole queue (1,750× at 1M rows). Interview answer: write the window; offer the recursion as the indexed fast path and say its three preconditions (index, gap-free turns, positive weights).

## 6. At scale

**(a) What breaks first.** *Measured (bench table):* approach 1 first: it is quadratic in the whole queue and already takes about 1 s at 1K rows, then times out at 100K. The window (approach 3) grows linearly, because it computes and sorts every row for a result that depends on the first few. The recursive CTE (approach 2) stays flat only with the `turn` index; without it, it grows faster than the window.

**(b) One machine, ~1M–100M rows.**
- `indexes.sql` adds `Queue (turn, weight, person_name)`: it is covering, so the window reads a narrow index in turn order instead of the table and each recursive step is a single index lookup. Measured: the index barely helps the window (0.89 s → 0.86 s at 1M) and turns the recursion from 2.34 s into 0.55 ms.
- Because weights are positive integers, at most 1000 people can board, so `WHERE turn <= 1000` before the window cuts approach 3 down to a bounded input (reasoned, not implemented as a solution here; it is the form used in `snowflake.sql`). It needs the same guarantees as approach 2: turns start at 1, no gaps.
- A recursive CTE is limited by `cte_max_recursion_depth` (1000 by default). The bound above (at most 1000 boarders) keeps approach 2 inside it, but a different capacity or lighter people (say, a capacity of 10,000 kg) would need that limit raised, or the window approach.

**(c) Distributed engines, billions of rows. *Reasoned, not measured.***
- *The global window is the bottleneck:* `SUM(...) OVER (ORDER BY turn)` has no `PARTITION BY`, so a distributed engine sends every row to one node to compute a single ordered running sum. That is the same problem as in `25-exchange-seats`, and far worse at billions of rows.
- *Fix: bound the input first.* A top-N is distributed-friendly: each task keeps its 1000 lowest turns and a final step merges them. Then run the window on those few thousand rows. In SQL this is `WHERE turn <= 1000` when turns are dense, or `ORDER BY turn LIMIT 1001` when they are not.
- *If the whole prefix sum were needed* (say, every person's boarding status), the scalable form is two-phase: compute per-partition sums, take a running sum of those, and add each partition's offset to its local running sums. Then only the small list of partition totals is serial.
- Pruning: if the table is clustered or sorted by `turn`, the range predicate `turn <= 1000` reads only the first micro-partitions.
- Nothing here needs `COUNT(DISTINCT)` or approximate functions.

**(d) The data-engineering answer.** The queue is a log that grows at the tail; the answer depends only on the head. Store the running total once per person and make the question a seek:

```sql
-- queue_totals(turn PRIMARY KEY, person_name, weight, running_total); append-only, by turn.
-- New people arrive in turn order after the current last turn. With positive weights the largest
-- running_total belongs to the last row, so the offset for a new batch is the largest stored total:
INSERT INTO queue_totals (turn, person_name, weight, running_total)
SELECT turn, person_name, weight,
       (SELECT COALESCE(MAX(running_total), 0) FROM queue_totals)
       + SUM(weight) OVER (ORDER BY turn ROWS UNBOUNDED PRECEDING)
FROM queue_batch;

-- The question is then a seek on the primary key, independent of the queue length:
SELECT person_name FROM queue_totals WHERE running_total <= 1000 ORDER BY turn DESC LIMIT 1;
```

Caveats: people inserted or removed in the middle of the queue, or a changed weight, change the running totals of every later person, so recompute from that turn onward. A batch applied twice double-counts unless it is keyed by its first turn. This is the same "maintain a prefix aggregate" idea as `29-restaurant-growth`.

## 7. Edge cases

Each "breaks" claim below is checked by execution: `mistakes/*.sql` are tempting wrong queries, and the harness asserts that each one fails every dataset it names (`harness/test_mistakes.py`).

| Case | Dataset | Wrong queries it catches (`mistakes/`) |
|---|---|---|
| Typical queue; `person_id` unrelated to `turn` | `tests/edge_typical.sql` | `first_overflow_person` (off by one), `window_without_order` (grand total) |
| Running total exactly 1000 still fits | `tests/edge_exact_1000.sql` | `strict_less_than`, `first_overflow_person`, `window_without_order` |
| After the first overflow, lighter people follow (they must not board) | `tests/edge_overflow_then_light.sql` | `greedy_skip_and_continue`, `first_overflow_person`, `window_without_order` |
| Only the first person fits | `tests/edge_first_person_only.sql` | `first_overflow_person`, `window_without_order` |
| Boarding order is `turn`, not `person_id` (the two give different answers) | `tests/edge_turn_vs_person_id.sql` | `order_by_person_id`, `window_without_order` |
| Nobody overflows: the answer is the last person | `tests/edge_everyone_fits.sql` | `person_before_first_overflow` (no overflow row exists), `first_overflow_person` (returns nothing) |
| Empty queue | `tests/edge_empty.sql` | none; every approach returns no row |

`window_without_order` is the instructive trap: it passes `edge_everyone_fits` (the grand total *is* the running total at the end) and fails everything else. Test with an overflow.

No approach in `solutions/` is broken by any of these.

## 8. Interviewer follow-ups

1. **"Return everyone who boards."** Drop the `ORDER BY ... LIMIT 1`: the rows of the running-total query with `total_weight <= 1000` are the boarders, in order.
2. **"Run several buses: when one is full the next one starts with the person who didn't fit."** A running total with `FLOOR(total / 1000)` is a classic wrong answer, because the leftover weight at each bus boundary changes where the next bus fills. The correct form is sequential and needs a recursive CTE (state: current bus, current load) or procedural code.
3. **"What if weights can be zero or negative?"** The prefix is no longer monotone. "The last row with total ≤ 1000" can then be a person *after* an overflow, which is not who boards. The right query finds the first overflow (`MIN(turn)` where the total exceeds 1000) and returns the person with the largest turn below it. Approach 2 stays correct for zero weights, but recursion depth is then no longer bounded by 1000.
4. **"Why not just sort by weight and pack the lightest first?"** That is a different problem (maximise how many board). The spec fixes the order.
5. **"The queue has billions of rows. What do you do?"** Bound the input to the head of the queue first (section 6c), then run the window or the recursion on that small set.

## 9. Snowflake notes (UNVERIFIED)

`snowflake.sql` is the window approach (03) on a bounded prefix, not the recursive CTE (02). What changes, and why:

- Snowflake has no secondary indexes, so each recursive step would be a join against the whole table (or a clustered range). The recursive CTE loses the lookup that makes it fast in MySQL. The recommended Snowflake form is the window approach on a bounded prefix: `WHERE turn <= 1000` (valid for positive integer weights and turns starting at 1 with no gaps), then the running sum.
- **`QUALIFY`** filters on the window result directly, so the extra subquery layer disappears: `QUALIFY SUM(weight) OVER (ORDER BY turn ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) <= 1000`. The `WHERE` runs before the window, which is what bounds it.
- If `Queue` is clustered by `turn`, the `turn <= 1000` predicate prunes micro-partitions and the scan reads only the head of the table.
- `WITH RECURSIVE` does exist in Snowflake, but there is no depth guard comparable to MySQL's `cte_max_recursion_depth` default, so a bug in the stop condition runs until the query times out.
- Unquoted identifiers are upper-cased in the result: `PERSON_NAME`.

## 10. Pattern links

Same pattern (running totals):
- `29-restaurant-growth`: a moving-window sum over daily totals instead of an unbounded prefix.
- `30-calculate-a-rolling-average-of-total-revenue`: the same moving window over a generated calendar.

Related:
- `25-exchange-seats`: window functions with no `PARTITION BY`, and the single-node cost that comes with them.
- `32-human-traffic-of-stadium`: finding a run of rows that meet a condition (gaps and islands), another "scan in order and stop" problem.
- `31-consecutive-numbers`: ordered comparisons between adjacent rows.
