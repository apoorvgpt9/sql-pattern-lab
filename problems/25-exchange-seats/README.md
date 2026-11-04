# 25 · Exchange Seats

## 1. Problem & trigger phrases

Original: [Exchange Seats](https://leetcode.com/problems/exchange-seats/) (LeetCode 626, medium). Read the statement there; this guide only restates the spec in its own words.

**Spec (own words):** return every seat id together with the student who ends up in that seat after seats 1↔2, 3↔4, 5↔6, … trade students. When the number of seats is odd, the last seat has nobody to trade with and keeps its student. Output is ordered by seat id.

| Trigger phrase | What it forces in SQL |
|---|---|
| "swap ... every two consecutive students" | Seats come in fixed pairs by id parity: an odd id pairs with `id + 1`, an even id pairs with `id - 1`. So each output seat needs exactly one value from a *neighbouring* row: `LEAD` for odd ids, `LAG` for even ids, or a lookup by partner id. Parity (`id % 2`) picks the direction. |
| "If the number of students is odd" | The last odd id has no neighbour. `LEAD` returns NULL there, and an `INNER JOIN` to the partner drops the row. The query needs an explicit fallback: `COALESCE(partner, own)`, or an id mapping that treats the last seat as a special case. |

Also notice what is **not** in the wording: no ordering of names, no filtering, no aggregation. This is a pure row-to-row remap, and the only trap is the ends of the table.

## 2. Schema & grain

| Table | One row means | Keys that matter here |
|---|---|---|
| `Seat` | one seat and the student sitting in it | `id` (PK, contiguous from 1 by spec), `student` |

**Output grain:** one row per `Seat` row, same ids. As a sanity check, the output has exactly as many rows as `Seat`, and the multiset of students is unchanged (swapping never invents or loses a student).

**Where the grain changes:** it does not. That is the point of the problem: every query that changes the row count (an inner join, a `GROUP BY`, a `DISTINCT`) is wrong. What changes is *which row's `student` value* lands in each row.

Two ways to see the swap, which give two families of solution:
- **Pull** (approaches 1 and 2): each output seat *fetches* its partner's student.
- **Push** (approach 3): each input row *moves* its student to a new seat id. Every input row produces exactly one output row, so nothing needs to be looked up.

The spec guarantees contiguous ids from 1. Approaches 1 and 2 and 3 all rely on it: "partner" is `id ± 1`, and "last seat" is `MAX(id)`.

## 3. Hint ladder

<details><summary>Hint 1</summary>

Pattern: **neighbour access** (`LAG` / `LEAD`), with a `CASE` on id parity to choose the direction. The output grain equals the input grain: no aggregation.

</details>

<details><summary>Hint 2</summary>

Shape: (1) decide for every seat whether it is the odd or the even member of its pair (`id % 2`). (2) The odd member gets the student of the next row, the even member gets the student of the previous row. (3) Handle the one seat that has no partner. (4) Order by id.

</details>

<details><summary>Hint 3</summary>

Key trick: the seat without a partner is always the row where `id = MAX(id)` and `id` is odd. With `LEAD` it shows up as NULL, so `COALESCE(LEAD(student) OVER (ORDER BY id), student)` fixes it. Or skip neighbours entirely: send every student to its new id (`id + 1` for odd, `id - 1` for even, unchanged for the odd last seat) and sort.

</details>

## 4. Decomposition

Read the wording for the unit of work. "Swap ... every two consecutive students" says the unit is a *pair*, and a pair is identified by id parity. Then ask what each output row needs: one value from one other row.

1. **Classify each seat by parity.**
   *Why a `CASE` here:* the pairs are fixed (1↔2, 3↔4), so a seat is either the first or the second of its pair. `id % 2` says which, and no data lookup is needed to decide.
2. **Find the partner's student.**
   *Why a window (or a self-lookup) here:* the value comes from a different row, but the row is always adjacent in id order. `LEAD`/`LAG` read the neighbour without a join. A join works too but has to say "partner id" explicitly.
3. **Cover the seat with no partner.**
   *Why `COALESCE` / a special case here:* only the last seat of an odd-sized table lacks a partner, and every neighbour-based method signals that with NULL or a missing row. Keeping its own student is the rule.
4. **Order by id.**
   *Why an `ORDER BY` here:* the spec asks for ascending ids. A window function does not promise output order.

Assembled (the window version):

```sql
SELECT id,
       CASE WHEN id % 2 = 1                                              -- step 1
            THEN COALESCE(LEAD(student) OVER (ORDER BY id), student)     -- steps 2 + 3
            ELSE LAG(student) OVER (ORDER BY id)                         -- step 2
       END AS student
FROM Seat
ORDER BY id;                                                             -- step 4
```

The optimal version (section 5) replaces steps 2 and 3 with a relabelling: instead of asking "who is my partner?", each row says "which seat am I going to?".

Self-check before you submit: run it on 1, 2 and 3 seats. One seat must return itself, two seats must swap, three must swap the first two and leave the third.

## 5. Approaches: brute force → optimal

### Approach 1: correlated subquery per seat (`solutions/01_correlated_subquery.sql`)

```sql
SELECT s.id,
       COALESCE((SELECT t.student FROM Seat t
                  WHERE t.id = CASE WHEN s.id % 2 = 1 THEN s.id + 1 ELSE s.id - 1 END),
                s.student) AS student
FROM Seat s
ORDER BY s.id;
```

**Why it is correct:** the outer query is `Seat` with no join or filter, so each seat appears once. The subquery fetches the partner's student by primary key. For the last odd seat the partner id does not exist, the subquery returns NULL, and `COALESCE` falls back to the seat's own student.

**Cost model (reasoned):** one primary-key lookup per seat, so *n* lookups, plus a sort if the optimizer does not already read `Seat` in PK order. Each lookup is cheap, so this is linear. It is the natural first attempt because it reads like the rule: "my new student is my partner's student".

### Approach 2: `LEAD` / `LAG` with a parity `CASE` (`solutions/02_lead_lag.sql`)

The SQL is the assembled query in section 4.

**Why it is correct:** in id order, the row after an odd id is the even id of its pair, and the row before an even id is the odd id of its pair. That is true only because ids are contiguous. `COALESCE` covers the last odd seat. The window needs no `PARTITION BY`, since the whole table is one sequence.

**Cost model (reasoned; the plan was checked with `EXPLAIN`):** linear in the number of seats, but with a heavy constant. MySQL treats `LEAD` and `LAG` as two separate windows, so the plan has two `Window aggregate with buffering` nodes, a sort feeding them, and a temporary table materialised for each. The `CASE` then discards one of the two computed values for every row. So it is not cheaper than approach 1's *n* primary-key lookups just because it avoids the lookups.

### Approach 3 (optimal): relabel each row's seat id (`solutions/03_relabel_ids.sql`)

```sql
WITH moved AS (
  SELECT CASE WHEN id % 2 = 0                      THEN id - 1
              WHEN id < (SELECT MAX(id) FROM Seat) THEN id + 1
              ELSE id END AS id,
         student
  FROM Seat
)
SELECT id, student FROM moved ORDER BY id;
```

**Why it is correct:** each student moves to the seat that the spec says it ends up in. An even-id student moves down to `id - 1`. An odd-id student moves up to `id + 1`, unless it is the last seat (`id = MAX(id)`), which keeps its own id. The target ids are a permutation of the source ids, so the output covers every seat exactly once. This is also why it cannot blank a student when a neighbour is NULL.

**Cost model (reasoned):** a per-row computation. No join, no window, no row depends on another row. The only shared value is `MAX(id)`, a single scalar that MySQL can read from the end of the primary-key index. The one extra cost is the `ORDER BY`: the new id is a computed value, so MySQL has to sort (the `EXPLAIN` plan shows `Sort: moved.id`). Whether that sort costs more than approach 2's window passes is an empirical question, and the table below answers it.

**Measured** (`gen.py` data, generated by the bench workflow; the table is filled in automatically, so never type numbers here):

<!-- BENCH:25-exchange-seats -->
<!-- /BENCH -->

### Why the optimal one wins

Approach 3 asks each row only about itself, so it has no join, no window frame and no neighbour dependence that could fail at the ends of the table. That matters most in distributed engines (section 6c), where "my neighbour" means a global sort or a shuffle, and "my new id" is free. On a single machine it still pays one final sort on the computed id, but it avoids approach 2's two buffered window passes and approach 1's *n* lookups; the measured table shows how that nets out.

## 6. At scale

**(a) What breaks first.** *Reasoned, then checked by the bench table:* nothing here is quadratic. All three are linear in the number of seats. The first thing to hurt is sorting: approach 3 must sort by a computed id, and approach 2 has an `ORDER BY id` window over the entire table as a single partition.

**(b) One machine, ~1M–100M rows.**
- The primary key on `id` already makes approach 1 a series of PK lookups, and the table is read in id order for approach 2's windows, so `indexes.sql` is not needed for this problem.
- Do not rewrite approach 2 with a self-join on `id + 1` "for speed": it is the same work with extra ways to fail on the odd tail.
- If a consumer only needs the swapped mapping, not a sorted result, drop the `ORDER BY` from approach 3. Then it is a pure scan with no sort.

**(c) Distributed engines, billions of rows. *Reasoned, not measured.***
- *Window with no `PARTITION BY`:* in Snowflake or Spark, `LEAD(...) OVER (ORDER BY id)` over the whole table has a single partition. Every row must reach one node to be ordered, which is the classic "global window" bottleneck, and it can run out of memory or time long before the data does.
- *Relabel is embarrassingly parallel:* approach 3 is a map. The only global value is `MAX(id)`, one cheap aggregate that can be computed once and broadcast. The final `ORDER BY` is a range-partitioned sort, which parallelises (sample the ids, shuffle by range) instead of funnelling to one node. A downstream job that doesn't need ordered output can skip it.
- *Join version:* a self-join on partner id is two shuffles on `id` (or one, if the table is already hashed by `id`), and every row crosses the network. It is worse than the map.
- *Contiguity is a data-quality assumption:* at billions of rows, deleted seats or gaps in ids are likely. Then "partner = id ± 1" is wrong, and the pairing must come from `ROW_NUMBER()`, a global sort again.

**(d) The data-engineering answer.** The swap is a stateless function of `(id, MAX(id))`, so it needs no history. Apply it per appended batch and only recompute the tail. Appending seats changes what the previous last seat should be (it may now have a partner), so only the last one or two output rows are ever affected:

```sql
-- seat_swapped(id PRIMARY KEY, student); new seats are in seat_batch, ids above the current max.
-- Snowflake / ANSI MERGE (UNVERIFIED): recompute from the last previously-unpaired id onward.
MERGE INTO seat_swapped t
USING (
  SELECT CASE WHEN id % 2 = 0 THEN id - 1
              WHEN id < (SELECT MAX(id) FROM seat) THEN id + 1
              ELSE id END AS id,
         student
  FROM seat
  WHERE id >= COALESCE((SELECT MAX(id) - 1 + MAX(id) % 2 FROM seat_swapped), 1)  -- largest odd id <= old max: re-read the old tail
) s
ON t.id = s.id
WHEN MATCHED THEN UPDATE SET student = s.student
WHEN NOT MATCHED THEN INSERT (id, student) VALUES (s.id, s.student);
```

Caveats: the lower bound is the largest odd id at or below the old maximum, so no pair is cut in half and a former unpaired last seat is re-read together with its new partner. If rows can be deleted or edited, recompute the pair that contains the changed id.

## 7. Edge cases

Each "breaks" claim below is checked by execution: `mistakes/*.sql` are tempting wrong queries, and the harness asserts that each one fails every dataset it names (`harness/test_mistakes.py`).

| Case | Dataset | Wrong queries it catches (`mistakes/`) |
|---|---|---|
| Even number of seats, all paired | `tests/edge_even_count.sql` | none: every approach passes; it is the baseline |
| Odd number of seats: last seat keeps its student | `tests/edge_odd_count.sql` | `inner_join_drops_last` (row vanishes), `lead_without_coalesce` (student becomes NULL), `relabel_ignores_odd_tail` (student sent to a seat that does not exist) |
| Exactly one seat | `tests/edge_single_seat.sql` | the same three: the one seat is both first and last |
| Empty table | `tests/edge_empty.sql` | none. A `MAX(id)` of NULL is harmless because no row evaluates it |
| Repeated names (including identical neighbours) | `tests/edge_duplicate_names.sql` | none. It documents that the swap is by id, so a query that matched seats by name would diverge |
| Output order differs from alphabetical order; rows inserted out of order | `tests/edge_ordering.sql` | `order_by_student` |

NULL student names are outside the spec (`nulls: n/a`) and are not tested. Be aware that the `COALESCE` form cannot tell "no partner" from "partner's student is NULL" and would keep the seat's own name. Only approach 3 would handle a NULL name correctly.

No approach in `solutions/` is broken by any of these.

## 8. Interviewer follow-ups

1. **"Ids may have gaps."** Then "partner = id ± 1" and "next row" disagree. Number the rows first: `ROW_NUMBER() OVER (ORDER BY id)` gives a contiguous `rn`; swap on `rn`, and join back to the original id. This costs a global sort, which is why the gap-free guarantee matters.
2. **"Swap in groups of 3 (rotate)."** Generalise the parity to `(rn - 1) % 3`, and use `LEAD`/`LAG` with offsets 1 and 2. The relabel version generalises to `rn + k` with wrap-around. Spell out what you want for a partial last group.
3. **"Do it without a window function or a join."** The relabel query: a `CASE` on parity plus `MAX(id)`.
4. **"Return the original and new seat for each student."** Keep both: `id AS old_seat`, and the `CASE` expression as `new_seat`. This is approach 3 without the rename.
5. **"What if two students share a name?"** No effect, because the logic is by id. This is why `edge_duplicate_names` exists.

## 9. Snowflake notes (UNVERIFIED)

`snowflake.sql` keeps the shape of approach 3. What changes, and why:

- `id % 2` and `MOD(id, 2)` both work. The `CASE` and scalar subquery carry over unchanged.
- `LEAD`/`LAG` in approach 2 work the same way, but `OVER (ORDER BY id)` with no `PARTITION BY` is a single-partition sort on one warehouse node. Approach 3 avoids that, so the preference for it is stronger in Snowflake than in MySQL (reasoned).
- There is no PK enforcement and no index to rely on for ordered reads, so approach 2's window always needs a real sort of the whole table in Snowflake.
- The final `ORDER BY` is only for presentation; if the result feeds another transformation, drop it.
- Unquoted identifiers are upper-cased: `ID` and `STUDENT` come back in capitals.

## 10. Pattern links

Same pattern (neighbour access with `LAG`/`LEAD`):
- `26-find-consistently-improving-employees`: `LEAD` over the three most recent reviews, with a strict-increase test.
- `27-most-common-course-pairs`: `LEAD` to form adjacent pairs, then count the transitions.
- `31-consecutive-numbers`: `LEAD` twice to test a run of three equal values.

Related:
- `28-last-person-to-fit-in-the-bus`: a window that depends on all earlier rows (running sum), where this problem only needs one neighbour.
