# 41 · Find the downward recommendation chain for member ID 1

## 1. Problem & trigger phrases

Original: [Find the downward recommendation chain for member ID 1](https://pgexercises.com/questions/recursive/getdownward.html) (pgexercises, medium; no difficulty label on the site, rated by the curator).

> Adapted from PostgreSQL Exercises by Alisdair Owens (pgexercises.com), CC BY-SA 3.0. Spec reworded. See `LICENSE.md`.

**Spec (own words):** members of a club can be recommended by an existing member. Return every member who sits anywhere below member 1 in the recommendation tree, at any number of steps. That means people member 1 recommended, people those members recommended, and so on. Member 1 is not included. Output each member's id, first name and surname, sorted by id. The original is PostgreSQL; this folder uses MySQL 8.0, drops the `cd.` schema prefix, and uses its own generated data with the same schema.

| Trigger phrase | What it forces in SQL |
|---|---|
| "recommended, and so on" | The number of hops is **not fixed**. A fixed number of self-joins answers "up to N levels", which is a different question. Unbounded depth over a parent pointer means `WITH RECURSIVE`: an anchor query for the first level, plus a step that joins the previous level to its children until a step adds no rows. |
| "downward" | It fixes the **direction of the recursive join**. The table stores the pointer *up* (`recommendedby`), so going down means "rows whose `recommendedby` equals a member I already found": `m.recommendedby = d.memid`. Swapping the two sides walks upward and returns 1's recommenders instead. The anchor is "recommended by 1", not member 1 itself, so 1 is excluded without an extra filter. |

## 2. Schema & grain

| Table | One row means | Keys that matter here |
|---|---|---|
| `members` | one member, with a pointer to whoever recommended them | `memid` (PK); `recommendedby` (NULL = nobody recommended them: the top of a chain); `firstname`, `surname` for the output. memid 0 is the shared GUEST account. |

**Output grain:** one row per member in member 1's subtree, excluding member 1. Because each member has at most one recommender, the recommendations form a forest of trees. Every descendant is reached by exactly one path, so the recursion produces each member once, and `UNION ALL` is enough (no dedup needed). Cycles are impossible in valid data; section 8 covers what happens if they appear anyway.

**Where the grain changes:** the input grain stays "one member" throughout. What changes is the *set* of members, growing one level per iteration. The recursive CTE's working table holds only the newest level, the *frontier*. Each iteration joins the frontier to `members` to find the next level, and stops when the frontier is empty. Recursion here is breadth-first: level 1, then level 2, and so on. That order is the order rows come out in, which is why the explicit `ORDER BY memid` is needed (section 7).

## 3. Hint ladder

<details><summary>Hint 1</summary>

Pattern: **recursive traversal down a hierarchy** stored as a parent pointer. The depth is unknown, so no fixed number of joins works.

</details>

<details><summary>Hint 2</summary>

Shape: (1) start from the members whose recommender is member 1. (2) Repeatedly add the members whose recommender is someone already found, until nothing new appears. (3) Sort the collected members by id.

</details>

<details><summary>Hint 3</summary>

Key clause: `WITH RECURSIVE downline AS (SELECT … FROM members WHERE recommendedby = 1 UNION ALL SELECT m.… FROM members m JOIN downline d ON m.recommendedby = d.memid)`. The join direction is `m.recommendedby = d.memid`: the new row's *pointer* equals an *already-found id*. Finish with `ORDER BY memid`, because recursion returns rows level by level.

</details>

## 4. Decomposition

Two words decide the query: "and so on" (unbounded, so recursive) and "downward" (which side of the join is the new row). Write the anchor and the step as two ordinary queries first. The recursive CTE is just those two glued with `UNION ALL`.

1. **Anchor: `SELECT … FROM members WHERE recommendedby = 1`.**
   *Why a filter here, and not `WHERE memid = 1`:* the output must exclude member 1. Starting from 1's direct recommendees produces level 1 directly, with nothing to remove later. Starting from member 1 itself also works, but then you need a final `WHERE memid <> 1`, and forgetting it is a common bug (`mistakes/anchor_includes_member_1.sql`).
2. **Recursive step: `members m JOIN downline d ON m.recommendedby = d.memid`.**
   *Why a JOIN here:* "recommended by someone already in the chain" is a match between a new row's pointer and an old row's id. In a recursive CTE, `downline` in the step means only the rows added by the previous iteration, so each level is computed from the one before it. Carrying `firstname`/`surname` along means no join back to `members` is needed at the end.
3. **Termination: none written.**
   *Why none is needed:* a leaf has no recommendees, so once the frontier contains only leaves, the step returns no rows and the recursion stops. That relies on the data being a forest (no cycles); see section 8.
4. **Final: `ORDER BY memid`.**
   *Why a sort here:* the spec orders by id, and breadth-first discovery is a different order whenever a deeper member has a smaller id than a shallower one.

```sql
WITH RECURSIVE downline (memid, firstname, surname) AS (
  SELECT memid, firstname, surname        -- step 1: level 1 = recommended by member 1 (1 itself excluded)
  FROM members
  WHERE recommendedby = 1
  UNION ALL
  SELECT m.memid, m.firstname, m.surname  -- step 2: the next level = recommended by the previous level
  FROM members m
  JOIN downline d ON m.recommendedby = d.memid   -- direction: new row's pointer = found id (downward)
)                                          -- step 3: stops when a level is empty
SELECT memid, firstname, surname
FROM downline
ORDER BY memid;                            -- step 4: level order is not id order
```

Self-check: run only the anchor and confirm it returns 1's direct recommendees. Then confirm that member 1 and anyone above 1 are absent from the full result.

## 5. Approaches: brute force → optimal

### Approach 1: build every (member, ancestor) pair, then filter (`solutions/01_all_ancestor_pairs_then_filter.sql`)

```sql
WITH RECURSIVE chain (memid, ancestor) AS (
  SELECT memid, recommendedby FROM members WHERE recommendedby IS NOT NULL
  UNION ALL
  SELECT c.memid, m.recommendedby
  FROM chain c JOIN members m ON m.memid = c.ancestor
  WHERE m.recommendedby IS NOT NULL
)
SELECT m.memid, m.firstname, m.surname
FROM chain c JOIN members m ON m.memid = c.memid
WHERE c.ancestor = 1
ORDER BY m.memid;
```

**Why it is correct:** for every member, `chain` lists all their ancestors, one row each, by walking up from the member while carrying the starting member along. A member belongs in the answer exactly when 1 is one of their ancestors. In a forest, each ancestor appears once per member, so there are no duplicates. This is a natural first attempt if you think member by member ("is 1 above me?"). It is also the general tool of problem 42: build the closure table once, then answer any ancestor question with a filter.

**Cost model (reasoned, plan shape checked with `EXPLAIN FORMAT=TREE`):** the recursion produces one row per (member, ancestor) pair, which is the **sum of all members' depths**, whatever member 1's subtree looks like. Each step is a primary-key lookup, which is cheap per row, but there are about members × average depth of them, all held in a temporary table. The final `WHERE c.ancestor = 1` cannot be pushed into the recursion, so the whole closure is built before the filter applies. `indexes.sql` barely helps: the walk upward already uses the primary key.

### Approach 3 (optimal): recursive walk downward from member 1 (`solutions/03_recursive_downward.sql`)

The SQL is the assembled query in section 4.

**Why it is correct:** the anchor is exactly level 1 of member 1's subtree. Each iteration adds the members whose recommender was found in the previous iteration, which is the next level. Every member of the subtree is reached through its unique path from member 1, and nobody outside the subtree is ever reached.

**Cost model (reasoned, plan shape checked):** the work is proportional to member 1's **subtree**, plus a fixed cost per level for finding children. That per-level cost is where the index matters:
- *Without* `indexes.sql`: each iteration is a hash join that **scans all of `members`** to find the rows whose `recommendedby` is in the current frontier. Cost ≈ (tree depth + 1) × members. The depth is small for this kind of data (`gen.py` reaches about 15 at 1M rows), but every level is a full pass.
- *With* `indexes.sql` (`members (recommendedby)`): the anchor and every step become index lookups on `recommendedby`. Cost ≈ subtree size × index probe, and no row outside the subtree is touched.

**Measured** (`gen.py` data, generated by the bench workflow; the table is filled in automatically, so never type numbers here):

<!-- BENCH:41-find-the-downward-recommendation-chain-for-member-id-1 -->
_Measured 2026-11-04 by the bench workflow: MySQL 8.0.46, AMD EPYC 7763 64-Core Processor, 2 vCPU. Median of 3 runs after 1 warm-up; each statement capped at 60 s. Sizes are main-table rows from `gen.py`. Raw numbers and EXPLAIN ANALYZE: `bench/results/41-find-the-downward-recommendation-chain-for-member-id-1.json`._

**Without indexes**

| Solution | 1,000 rows | 100,000 rows | 1,000,000 rows | × slower than optimal @ 1,000,000 |
|---|---:|---:|---:|---:|
| `01_all_ancestor_pairs_then_filter` | 4.16 ms | 265 ms | 7.52 s | 1.5× |
| `03_recursive_downward` (optimal) | 4.11 ms | 414 ms | 5.02 s | 1.0× |

**With `indexes.sql`**

| Solution | 1,000 rows | 100,000 rows | 1,000,000 rows | × slower than optimal @ 1,000,000 |
|---|---:|---:|---:|---:|
| `01_all_ancestor_pairs_then_filter` | 3.89 ms | 189 ms | 6.16 s | 6.6× |
| `03_recursive_downward` (optimal) | 2.89 ms | 106 ms | 937 ms | 1.0× |

> GitHub-hosted runners are shared, noisy VMs: compare the ratios between rows, not the absolute times.
<!-- /BENCH -->

### Why the optimal one wins

Approach 3 asks the question in the direction the answer lies. It starts at member 1 and touches only members below it. Approach 1 builds every member's full ancestry and then throws away everything not under member 1. Approach 3's remaining weakness is the per-level full scan without an index on `recommendedby`, and the bench shows it matters: without the index, approach 1 was actually *faster* at 100K rows (265 ms vs 414 ms), because its upward steps are primary-key lookups while approach 3 scans the whole table once per level. At 1M rows the closure that approach 1 builds has grown enough that approach 3 wins anyway (5.02 s vs 7.52 s, 1.5×). With the index, approach 3's cost depends on the size of the answer, not of the table: 0.94 s vs 6.16 s at 1M (6.6×). Approach 1 still wins in one case: when you need the chains of *many* starting members at once. There the closure is built once and shared, which is problem 42.

## 6. At scale

**(a) What breaks first.** *Reasoned, then checked by the bench table:* approach 1's closure grows as members × depth and lives in one temporary table. It outgrows memory first and spills. Approach 3 without the index pays one full scan per level. That grows with depth × members, but needs little memory; at 100K rows that still made it slower than approach 1, and only at 1M did approach 1's closure cost overtake it. With the index, approach 3 is bounded by the subtree size.

**(b) One machine, ~1M–100M rows.**
- `indexes.sql` adds `members (recommendedby)`. Any table with a parent pointer that you traverse downward needs this index. The bench runs every approach with and without it.
- **Recursion limits:** MySQL stops a recursive CTE after `cte_max_recursion_depth` iterations (default 1000) with an error, not a truncated result. Real recommendation or org trees are shallow, but a corrupted row that creates a cycle hits this limit. `SET SESSION cte_max_recursion_depth = …` raises it. Section 8 covers proper cycle guards.
- Each iteration's frontier is materialised in a temporary table, so a very wide level (one member who recommended a million people) is one large temp table. That is still linear.
- When the same subtree questions are asked constantly, stop recomputing: keep a closure table or a path column; see (d).

**(c) Distributed engines, billions of rows. *Reasoned, not measured.***
- *Iterations become jobs:* in Spark-style engines, recursion runs as a loop of joins, one per level. Each level is a shuffle join of the frontier against the full edge table, so the cost is roughly depth × shuffle(edges), the distributed version of the no-index case. Broadcasting the (small) frontier to the edge partitions avoids shuffling the big side, as long as the frontier fits in memory.
- *Snowflake:* recursive CTEs and `CONNECT BY` are both supported. There are no indexes, so each level is a hash join against `members`, and micro-partition pruning cannot help a predicate like `recommendedby IN (frontier)` unless the table happens to be clustered by `recommendedby`.
- *Graph-shaped data at that size* (social graphs, not org charts) is usually traversed with graph engines or precomputed closures, not ad-hoc recursion. Depth is unbounded there, and fan-out explodes.

**(d) The data-engineering answer.** Recommendation trees only grow at the leaves (a new member is recommended by an existing one), which suits a **closure table**: one row per (ancestor, descendant). The downward chain becomes a single indexed lookup:

```sql
-- member_closure(ancestor, descendant, depth, PRIMARY KEY (ancestor, descendant)).
-- When new members arrive (new_members), each inherits its recommender's ancestors plus the recommender itself.
-- Snowflake / ANSI (UNVERIFIED):
INSERT INTO member_closure (ancestor, descendant, depth)
SELECT c.ancestor, n.memid, c.depth + 1
FROM new_members n
JOIN member_closure c ON c.descendant = n.recommendedby
UNION ALL
SELECT n.recommendedby, n.memid, 1
FROM new_members n
WHERE n.recommendedby IS NOT NULL;

-- MySQL: the same INSERT ... SELECT works as written.
-- The question becomes a non-recursive range read on the PK:
SELECT m.memid, m.firstname, m.surname
FROM member_closure c JOIN members m ON m.memid = c.descendant
WHERE c.ancestor = 1
ORDER BY m.memid;
```

Caveats interviewers probe. *Batch order:* a new member recommended by another new member in the same batch needs their recommender's closure rows first. Process the batch in join order, or loop until no rows are added. *Moving a member* (correcting the recommender) means deleting and re-inserting the closure rows for the whole moved subtree, which is the closure table's main cost. *Storage* is members × average depth, the same quantity approach 1 computes on every query.

## 7. Edge cases

Each "breaks" claim below is checked by execution: `mistakes/*.sql` are the tempting wrong queries, and the harness asserts that each one fails every dataset it names (`harness/test_mistakes.py`).

| Case | Dataset | Wrong queries it catches (`mistakes/`) |
|---|---|---|
| Two branches under member 1, an unrelated second tree, GUEST, NULL `recommendedby` at every chain top | `tests/edge_typical.sql` | `walks_upward` (member 1 has no recommender, so it returns nothing), `anchor_includes_member_1` |
| Member 1 recommended nobody | `tests/edge_no_recommendees.sql` | `anchor_includes_member_1` (returns member 1 instead of an empty result) |
| Chain nine levels below member 1 | `tests/edge_deep_chain.sql` | `fixed_depth_self_joins` (stops after three levels). It passes `edge_typical` and `edge_order` because both are at most three deep, which is why depth needs its own dataset. |
| Member 1 in the middle of a chain, with a sibling | `tests/edge_direction.sql` | `walks_upward` (returns 5 and 3, the members *above* 1) |
| Discovery order ≠ memid order; rows inserted shuffled | `tests/edge_order.sql` | none in `mistakes/` (see below) |

NULLs: `recommendedby` NULL marks the top of a chain. The downward walk never compares against it, because it only follows `recommendedby = <found id>`, and NULL never equals anything. So NULL tops cannot leak into the result. The upward walk in approach 1 has to stop on them explicitly (`WHERE m.recommendedby IS NOT NULL`), or it would emit a `(member, NULL)` pair. That is harmless here because of the `ancestor = 1` filter, but wrong for problem 42's output.

No approach in `solutions/` is broken by any of these.

One trap that is not in `mistakes/`: forgetting the final `ORDER BY memid`. A recursive CTE tends to return rows level by level, in the order it discovered them (on `edge_order.sql` that looks like 9, 12, 3, 2, 11), but that order is not guaranteed, so no dataset can reliably catch the omission. It is still a wrong answer: without `ORDER BY`, SQL promises no order.

## 8. Interviewer follow-ups

1. **"Also return each member's level below member 1."** Carry a counter: `1 AS lvl` in the anchor and `d.lvl + 1` in the step. Useful for "only the first three levels" too: add `WHERE d.lvl < 3` in the step. That is the *correct* way to bound depth, unlike hard-coded self-joins.
2. **"What if the data contains a cycle (A recommended B, B recommended A)?"** The frontier never empties. MySQL aborts with error 3636 ("Recursive query aborted after 1001 iterations"), not a partial result. Guard it by carrying the path, seeded with the start member: `CAST(CONCAT('1,', memid) AS CHAR(1000)) AS path` in the anchor, `CONCAT(d.path, ',', m.memid)` in the step, and `WHERE FIND_IN_SET(m.memid, d.path) = 0`. Two details were checked by running them. Without the start member in the path, member 1 reappears as its own descendant. Without the explicit `CHAR(1000)`, MySQL sizes the column from the anchor row, and strict mode fails with "Data too long for column 'path'" once the path grows. Postgres has `CYCLE … SET … USING` for this; MySQL does not.
3. **"Return the chain for every member at once."** Anchor on all members, carry the start member as a column, and filter only at the end. That is problem 42, `42-produce-a-cte-that-can-return-the-upward-recommendation-chain-for-any-member`.
4. **"Count how many members each member brought in, directly and indirectly."** Use the closure table (approach 1 or section 6d), then `GROUP BY ancestor`. That is subtree aggregation, as in `43-analyze-organization-hierarchy`.
5. **"Why UNION ALL and not UNION in the recursive CTE?"** In a forest every member is reached once, so `UNION` only adds a dedup cost. With shared descendants (diamonds) or cycles, `UNION` discards any row already produced, so it also terminates a cycle (checked: a 1 → 2 → 3 → 1 loop returns each member once instead of hitting error 3636). It only works when the carried columns are identical on revisits: add a level counter or a path, and every revisit is a "new" row again.

## 9. Snowflake notes (UNVERIFIED)

`snowflake.sql` keeps the recursive CTE and shows the `CONNECT BY` equivalent in a comment. What changes, and why:

- `CONNECT BY recommendedby = PRIOR memid` with `START WITH recommendedby = 1` is the Oracle-style form of the same downward walk. It also offers `LEVEL`, `SYS_CONNECT_BY_PATH` and `CONNECT_BY_ROOT`, which make follow-ups 1–3 one-liners.
- Snowflake allows `WITH RECURSIVE`; the `RECURSIVE` keyword is optional there. It also has a recursion limit; check the current default in the docs before relying on deep hierarchies.
- No indexes exist, so each level is a hash join against the full `members` table, like the MySQL no-index case. The cost is levels × table scan, which for a small table like this is negligible.
- In Postgres (the original's dialect) the same query runs unchanged apart from the `cd.` prefix. Postgres 14+ also has `SEARCH BREADTH FIRST` / `CYCLE` clauses.

## 10. Pattern links

Same recursive-hierarchy family (parent-pointer table, `WITH RECURSIVE`):
- `42-produce-a-cte-that-can-return-the-upward-recommendation-chain-for-any-member`: walk **up**, from **every** member, carrying the start member. Approach 1 here is that closure table.
- `43-analyze-organization-hierarchy`: level, subtree size and subtree sums, built on the closure table.
- `39-tree-node`: the same data shape, where the question only needs one hop, so no recursion.

Same "direction of the join decides the answer" idea:
- `01-market-analysis-i`: which side of a LEFT JOIN drives the output grain.
