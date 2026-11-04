# 42 · Produce a CTE that can return the upward recommendation chain for any member

## 1. Problem & trigger phrases

Original: [Produce a CTE that can return the upward recommendation chain for any member](https://pgexercises.com/questions/recursive/getupwardall.html) (pgexercises, hard; no difficulty label on the site, rated by the curator).

> Adapted from PostgreSQL Exercises by Alisdair Owens (pgexercises.com), CC BY-SA 3.0. Spec reworded. See `LICENSE.md`.

**Spec (own words):** write one recursive CTE that pairs each member with every member above them in the recommendation chain: their recommender, that person's recommender, and so on to the top. Then use it to list, for members 12 and 22, each ancestor's id with that ancestor's first name and surname. Sort by member ascending, then by ancestor id descending. The original is PostgreSQL; this folder uses MySQL 8.0, without the `cd.` prefix, and with its own generated data.

| Trigger phrase | What it forces in SQL |
|---|---|
| "for any member" | The recursion must not start from one fixed member. The anchor is *every* member, and the start member has to be **carried through every iteration** as its own column (`member`), because after a few hops up, the current row says nothing about where the walk began. That carried column is what turns a traversal into a *closure table*: one row per (member, ancestor). |
| "upward recommendation chain" | It fixes the join direction: from the current ancestor, go to *their* recommender: `JOIN members m ON m.memid = r.recommender`, then emit `m.recommendedby`. Going up follows the stored pointer, so every step is a primary-key lookup (compare 41, where going down needed an index on `recommendedby`). |
| "chains for members 12 and 22" | The member filter is a separate step from building the chains. The spec builds the general CTE and filters at the end. In MySQL, that end filter does **not** reach inside the recursion. Moving it into the anchor is the optimisation; see Assumptions and section 5. |

Also notice the output column trap: `firstname, surname` describe the **recommender**, not the member. Every row of member 12's output has a different name, which is how you can tell the join is right.

## 2. Schema & grain

| Table | One row means | Keys that matter here |
|---|---|---|
| `members` | one member, with a pointer to their recommender | `memid` (PK); `recommendedby` (NULL = top of a chain); `firstname`, `surname` |

**Output grain:** one row per (member, ancestor) pair, for members 12 and 22 only. A member with no recommender contributes no rows. There is no row with a NULL recommender.

**Where the grain changes:** the input is one row per member, and the CTE is one row per **(member, ancestor)**. That is a fan-*out*: a member at depth d produces d rows. Each iteration takes the rows found so far, follows one more pointer up, and keeps the `member` column unchanged. The output then joins `members` a second time, on the **ancestor** column, to fetch the names. The same table is used twice in two different roles: once to climb (`m.memid = r.recommender`, read `recommendedby`) and once to describe the ancestor (`memid = recommender`, read names). Mixing up those two roles is the commonest bug here.

## Assumptions

1. **The graded result is the output rows. "Build a CTE for every member" is a design constraint, not an output requirement.** The spec asks for a CTE that maps *every* member to its ancestors, then filters to 12 and 22. Approach 1 does exactly that. Approach 3 builds the same CTE with the member list as a parameter in the anchor (`WHERE memid IN (12, 22)`). It is still "for any member": change the list and it works for anyone. It returns the identical result. *Tested:* the harness's differential test runs both approaches on five random datasets and asserts identical output; both also pass every edge dataset. The trigger phrase "filter only at the end" describes approach 1. Section 5 explains why approach 3 moves the filter anyway: MySQL does not push it into the recursion.
2. **"Chain stops when recommendedby is NULL; do not emit a NULL recommender row" applies at both ends.** A member who has no recommender gets no rows (not one NULL row), and the top of every chain ends the walk without an extra NULL row. *Tested:* `tests/edge_no_recommender.sql` (member 22 has no recommender), `tests/edge_both_tops.sql` (empty result), and `mistakes/null_top_row.sql`, which emits exactly those NULL rows and must fail all five datasets.

## 3. Hint ladder

<details><summary>Hint 1</summary>

Pattern: **recursive closure table**: a recursive CTE that walks up a parent pointer while *carrying the starting row's id* through every iteration.

</details>

<details><summary>Hint 2</summary>

Shape: (1) for every member, emit (member, their recommender). (2) Repeatedly replace the recommender with *that* person's recommender, keeping the member column unchanged, until a recommender has none. (3) Attach the ancestor's names, keep members 12 and 22, and sort.

</details>

<details><summary>Hint 3</summary>

Key clause: anchor `SELECT memid AS member, recommendedby AS recommender FROM members WHERE recommendedby IS NOT NULL`, step `SELECT r.member, m.recommendedby FROM recommenders r JOIN members m ON m.memid = r.recommender WHERE m.recommendedby IS NOT NULL`. The names come from a final `JOIN members ON memid = recommender`, not on `member`. Since MySQL won't push `member IN (12, 22)` into the recursion, put it in the anchor yourself.

</details>

## 4. Decomposition

Read the title as two separate jobs: "a CTE that can return the chain for **any** member" (build something general) and "for members 12 and 22" (use it). The first job decides the CTE's columns. The second is a filter plus a lookup.

1. **Anchor: `(member, recommender)` = `(memid, recommendedby)` for members that have a recommender.**
   *Why a filter here (`recommendedby IS NOT NULL`):* a member with no recommender has no ancestors. Emitting `(member, NULL)` would put the forbidden NULL row in the output, so filter it out at the source.
2. **Step: `JOIN members m ON m.memid = r.recommender`, emit `(r.member, m.recommendedby)`.**
   *Why a JOIN here:* "the recommender's recommender" is the same pointer, read from a different row: the row whose id is the current ancestor. *Why carry `r.member` unchanged:* "for any member" means each output row has to remember where its walk started. Without that column you get a list of ancestors with no owner. *Why `WHERE m.recommendedby IS NOT NULL`:* it stops at the top without emitting a NULL ancestor, and it is what ends the recursion.
3. **Describe each ancestor: `JOIN members a ON a.memid = r.recommender`.**
   *Why a second JOIN to the same table:* the names belong to the ancestor. This join uses `members` in its "lookup by id" role, not its "climb" role.
4. **Pick and order: `member IN (12, 22)`, `ORDER BY member ASC, recommender DESC`.**
   *Why the filter's position matters:* placed after the CTE (spec-literal), it is correct but runs after the whole closure is built. Placed in the anchor (step 1), only the two requested chains are walked. Same rows either way (Assumptions 1).

```sql
WITH RECURSIVE recommenders (member, recommender) AS (
  SELECT memid, recommendedby              -- step 1: each requested member + direct recommender
  FROM members
  WHERE memid IN (12, 22)                  -- step 4's filter, moved here (spec-literal: drop this line, filter at the end)
    AND recommendedby IS NOT NULL
  UNION ALL
  SELECT r.member, m.recommendedby         -- step 2: one hop up, start member carried
  FROM recommenders r
  JOIN members m ON m.memid = r.recommender
  WHERE m.recommendedby IS NOT NULL        -- stop at the top: no NULL ancestor row
)
SELECT r.member, r.recommender, a.firstname, a.surname   -- step 3: names of the ANCESTOR
FROM recommenders r
JOIN members a ON a.memid = r.recommender
ORDER BY r.member ASC, r.recommender DESC;               -- step 4: not chain order
```

Self-check: for each member, the number of rows equals their depth in the tree. The first-name column should change on every row of one member's chain.

## 5. Approaches: brute force → optimal

### Approach 1: closure for everyone, then filter (`solutions/01_closure_for_everyone_then_filter.sql`)

The assembled query in section 4, with the `memid IN (12, 22)` line removed from the anchor and `WHERE r.member IN (12, 22)` added after the final join. This is the spec read literally: one general CTE, used for two members.

**Why it is correct:** the anchor covers every member who has a recommender. Each iteration extends every open chain by one hop, keeping its owner. A forest has exactly one path upward from any member, so every (member, ancestor) pair appears exactly once. The filter and the names join run on that complete closure.

**Cost model (reasoned, plan shape checked with `EXPLAIN FORMAT=TREE`):** the plan shows "Materialize recursive CTE recommenders", then "Filter: member in (12, 22)" *on top of* the materialised table. MySQL builds the entire closure, **members × average depth** rows (about 1.8 rows per member on `gen.py` data, more on deeper trees), and only then keeps the two chains. Each step is a primary-key lookup, so the closure is cheap per row, but the row count grows with the whole table, not with the answer. No secondary index changes this. The upward walk only ever looks up `memid`.

### Approach 3 (optimal): anchor on the requested members (`solutions/03_anchor_on_requested_members.sql`)

The SQL is the assembled query in section 4.

**Why it is correct:** the recursion is anchor-driven. Every row it produces descends from an anchor row through a chain of steps that keep `member` unchanged. Restricting the anchor to 12 and 22 therefore produces exactly the rows of approach 1's closure where `member IN (12, 22)`: no more, no fewer. The parameter list still makes it "for any member".

**Cost model (reasoned, plan shape checked):** the anchor is a primary-key range read of two rows. Each iteration does one PK lookup per open chain. Total work ≈ depth(12) + depth(22) lookups, independent of table size. The plan contains no full table scan at all.

**Measured** (`gen.py` data, generated by the bench workflow; the table is filled in automatically, so never type numbers here):

<!-- BENCH:42-produce-a-cte-that-can-return-the-upward-recommendation-chain-for-any-member -->
_Measured 2026-11-04 by the bench workflow: MySQL 8.0.46, AMD EPYC 7763 64-Core Processor, 2 vCPU. Median of 3 runs after 1 warm-up; each statement capped at 60 s. Sizes are main-table rows from `gen.py`. Raw numbers and EXPLAIN ANALYZE: `bench/results/42-produce-a-cte-that-can-return-the-upward-recommendation-chain-for-any-member.json`._

**Without indexes**

| Solution | 1,000 rows | 100,000 rows | 1,000,000 rows | × slower than optimal @ 1,000,000 |
|---|---:|---:|---:|---:|
| `01_closure_for_everyone_then_filter` | 2.3 ms | 183 ms | 5.56 s | 8007.3× |
| `03_anchor_on_requested_members` (optimal) | 709 µs | 725 µs | 695 µs | 1.0× |

> GitHub-hosted runners are shared, noisy VMs: compare the ratios between rows, not the absolute times.
<!-- /BENCH -->

There is no `indexes.sql` for this problem (section 6b explains why), so the bench has only the "without indexes" table.

### Why the optimal one wins

Both approaches run the same recursion. They differ only in where the member filter sits. A filter after a recursive CTE cannot shrink the recursion in MySQL, because the optimizer does not push predicates into a recursive anchor. So approach 1 pays for every member's chain to answer a question about two. Approach 3 writes the pushdown by hand and does work proportional to the answer. The reusable form still has its place: building the closure **once** and storing it (section 6d) serves every member's question afterwards, and then approach 1's cost is paid at load time, not query time.

## 6. At scale

**(a) What breaks first.** *Reasoned, then checked by the bench table:* approach 1's materialised closure (members × average depth rows) grows with the table and spills once it exceeds `tmp_table_size`. Approach 3's cost is the two chains' depth, so table size barely matters.

**(b) One machine, ~1M–100M rows.**
- **No index helps here, and that is the lesson.** Climbing follows `memid`, the primary key. An index on `recommendedby`, essential for walking *down* (`41-find-the-downward-recommendation-chain-for-member-id-1`), is never used by an upward walk. So this folder has no `indexes.sql`. Know which direction your traversal goes before adding hierarchy indexes.
- **Predicate pushdown is the fix.** For a reusable "chain of any member" in MySQL, use a stored procedure or parameterised SQL that injects the member list into the anchor. A view with a recursive CTE cannot be filtered efficiently from outside.
- Watch `cte_max_recursion_depth` (default 1000): one cycle in the data turns either approach into error 3636. See 41's follow-ups for a path-based cycle guard.

**(c) Distributed engines, billions of rows. *Reasoned, not measured.***
- *Closure size:* members × average depth. For an org chart (depth ~10) that is ~10× the base table. For deep or graph-shaped data (citation chains, bills of materials) it can explode. Compute it once, materialise it, and partition or cluster it by `member` (or `ancestor` for descendant queries) so that lookups prune.
- *Iteration cost:* each recursion level is a join of the open chains against `members` on `memid`. In Spark-style engines that is a shuffle per level, unless `members` is small enough to broadcast. With a two-member anchor the frontier is tiny, so broadcasting it to `members` makes each level cheap. With an every-member anchor, each level shuffles the whole frontier.
- *Pushdown:* Snowflake's optimizer may push a filter into a recursive CTE's anchor, depending on its rules; MySQL's does not. Check the query profile before relying on it. Writing the filter in the anchor removes the question.

**(d) The data-engineering answer.** Persist the closure and maintain it incrementally. A new member's ancestors are their recommender plus the recommender's ancestors, which are already in the table:

```sql
-- member_ancestors(member, ancestor, depth, PRIMARY KEY (member, ancestor)), fed by batches of new members.
-- Snowflake / ANSI MERGE (UNVERIFIED):
MERGE INTO member_ancestors t
USING (
  SELECT n.memid AS member, n.recommendedby AS ancestor, 1 AS depth
  FROM new_members n WHERE n.recommendedby IS NOT NULL
  UNION ALL
  SELECT n.memid, a.ancestor, a.depth + 1
  FROM new_members n JOIN member_ancestors a ON a.member = n.recommendedby
) s
ON t.member = s.member AND t.ancestor = s.ancestor
WHEN NOT MATCHED THEN INSERT (member, ancestor, depth) VALUES (s.member, s.ancestor, s.depth);

-- MySQL equivalent: the same SELECT feeding INSERT IGNORE INTO member_ancestors (member, ancestor, depth).
-- Then the question is a PK range read, no recursion:
SELECT a.member, a.ancestor AS recommender, m.firstname, m.surname
FROM member_ancestors a JOIN members m ON m.memid = a.ancestor
WHERE a.member IN (12, 22)
ORDER BY a.member, a.ancestor DESC;
```

Caveats interviewers probe. *Intra-batch dependencies:* if a new member's recommender is also new in the same batch, their ancestors are not in the table yet. Apply the batch in join order, or repeat the MERGE until it inserts nothing. *Corrections:* changing a member's recommender changes the ancestors of that member's whole subtree. Delete and rebuild those rows (find the subtree with the closure itself: `WHERE ancestor = moved_member`). *Idempotency:* the `NOT MATCHED`-only MERGE (or `INSERT IGNORE`) makes replays harmless.

## 7. Edge cases

Each "breaks" claim below is checked by execution: `mistakes/*.sql` are the tempting wrong queries, and the harness asserts that each one fails every dataset it names (`harness/test_mistakes.py`).

| Case | Dataset | Wrong queries it catches (`mistakes/`) |
|---|---|---|
| Two chains that share ancestors; an unrelated tree; GUEST | `tests/edge_typical.sql` | `names_of_the_member` (every row shows 12's or 22's own name), `null_top_row` (an extra NULL row per member) |
| Member 22 has no recommender (and has a descendant, 30) | `tests/edge_no_recommender.sql` | `null_top_row` (gives 22 a `(22, NULL, NULL, NULL)` row instead of none), `names_of_the_member` |
| Neither 12 nor 22 has a recommender | `tests/edge_both_tops.sql` | `null_top_row` (two NULL rows instead of an empty result) |
| Ancestor ids not decreasing up the chain; rows shuffled | `tests/edge_order.sql` | `chain_order_not_id_order` (nearest-first order). It passes `edge_typical` and `edge_deep_chain`, where ids happen to decrease upward, which is why ordering gets its own dataset. |
| 11- and 12-step chains; 12 is itself an ancestor of 22 | `tests/edge_deep_chain.sql` | `fixed_depth_self_joins` (only three levels), `names_of_the_member` |

No approach in `solutions/` is broken by any of these.

## 8. Interviewer follow-ups

1. **"Also return how many steps up each ancestor is."** Carry `1 AS depth` in the anchor and `r.depth + 1` in the step. This is also the column you need to sort nearest-first, the order `mistakes/chain_order_not_id_order.sql` uses on purpose.
2. **"Return each member's chain as one string, top to bottom."** Carry a path: `CAST(recommendedby AS CHAR(1000))` in the anchor, `CONCAT(m.recommendedby, ' > ', r.path)` in the step, then keep the longest path per member (the row where the walk ended). The `CAST` width matters in MySQL, because recursive columns are sized from the anchor; see 41's follow-ups.
3. **"Who is the top-most ancestor (the root) of each member?"** The row per member with the greatest depth. Or, in the recursion, carry only the latest ancestor and keep the final row. In Snowflake's `CONNECT BY`, it is `CONNECT_BY_ROOT` walking in the other direction.
4. **"Find all descendants of member 1 instead."** Flip the direction: walk down via `recommendedby = current id`, which needs an index on `recommendedby`. That is `41-find-the-downward-recommendation-chain-for-member-id-1`. Or reuse this closure with `WHERE ancestor = 1`, which is 41's approach 1.
5. **"Why not put the names into the recursion?"** You can carry the ancestor's names, since each step already reads that member's row (`m` is the current ancestor's row when you emit `m.recommendedby`). But you would emit the *next* ancestor's id with the *current* row's names, an off-by-one that is easy to get wrong. A final join on the ancestor id is clearer and costs one PK lookup per output row.

## 9. Snowflake notes (UNVERIFIED)

`snowflake.sql` keeps approach 3 and shows a `CONNECT BY` version in a comment. What changes, and why:

- `CONNECT BY memid = PRIOR recommendedby` with `START WITH memid IN (12, 22)` walks upward. `CONNECT_BY_ROOT memid` is exactly the carried "start member" column that you build by hand in the CTE, and `LEVEL > 1` drops the start member's own row. It is shorter, and it makes the carried column impossible to forget.
- Snowflake's optimizer may push an outer filter into a recursive CTE. Do not depend on it; check the query profile, or keep the filter in the anchor as here.
- For repeated use, materialise the closure as a table (or a dynamic table refreshed on a schedule) clustered by `member`. Point lookups then prune to a few micro-partitions.
- In Postgres (the original's dialect), approach 1 runs as written apart from the `cd.` prefix, and, like MySQL, Postgres does not push the outer filter into the recursive term.

## 10. Pattern links

Same recursive-closure family:
- `41-find-the-downward-recommendation-chain-for-member-id-1`: the opposite direction, from one fixed start. Its approach 1 *is* this closure table, filtered on `ancestor`.
- `43-analyze-organization-hierarchy`: builds the closure to aggregate **over** it (team size, subtree salary sums). Same carried-anchor-column trick.
- `39-tree-node`: the same parent-pointer table where only one hop matters, so no recursion.

Same "a filter's position changes the cost but not the result" lesson:
- `01-market-analysis-i`: filter placement in `ON` vs `WHERE`. There the position changes the *result*; here it changes only the cost. Knowing which case you are in is the skill.
