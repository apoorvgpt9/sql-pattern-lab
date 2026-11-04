# 39 · Tree Node

## 1. Problem & trigger phrases

Original: [Tree Node](https://leetcode.com/problems/tree-node/) (LeetCode 608, medium). Read the statement there; this guide only restates the spec in its own words.

**Spec (own words):** a table stores a tree, one row per node, each row pointing at its parent. Label every node: `Root` if it has no parent, `Inner` if it has a parent and at least one child, `Leaf` otherwise. One output row per node.

| Trigger phrase | What it forces in SQL |
|---|---|
| "Root ... Inner ... Leaf" | Three mutually exclusive labels → one `CASE`, and the **order of its branches is part of the logic**. `CASE` stops at the first true branch, so `p_id IS NULL → Root` must come first: the root usually has children too, and would otherwise be labelled `Inner`. |
| "valid tree" | Exactly one root, every `p_id` names a real node, no cycles. That is what lets you skip orphan and cycle handling. It also covers the one-node tree: a lone root has no children, and it is still `Root`, not `Leaf`. |

Notice what the wording does **not** ask for: depth, ancestors, subtree sizes. Every label depends only on the node's immediate neighbours, one hop up (`p_id`) and one hop down ("is my id anyone's `p_id`?"). So this hierarchy problem needs **no recursion**. Spotting that is the first decomposition skill for trees; problems 41–43 are the ones that do need `WITH RECURSIVE`.

## 2. Schema & grain

| Table | One row means | Keys that matter here |
|---|---|---|
| `Tree` | one node and a pointer to its parent | `id` (PK); `p_id` (NULL only for the root) |

**Output grain:** one row per `Tree` row. The output row count must equal `SELECT COUNT(*) FROM Tree`.

**Where the grain changes:** the table stores the edge **upward** (child → parent). "Has a child" is a fact stored in *other* rows: node 20 is Inner because rows 40 and 50 say `p_id = 20`. To get it you read the table a second time, as a list of parent ids. That list has **one row per child**, so a parent with k children appears k times. Collapse it to one row per parent (`DISTINCT` / `GROUP BY p_id`), or use a semijoin (`EXISTS` / `IN`) that stops at the first match. Joining straight to the children multiplies every Inner node by its child count; that is the classic fan-out bug of this problem.

Also note the NULL: the root's `p_id` is NULL. So the list `SELECT p_id FROM Tree` *always* contains a NULL in a valid tree, which is what makes `NOT IN` on that list a guaranteed bug rather than an occasional one.

## 3. Hint ladder

<details><summary>Hint 1</summary>

Pattern: **existence check on a self-referencing table**, then classification with `CASE`. Each label needs only "does this node have a parent?" and "does any other row point at this node?".

</details>

<details><summary>Hint 2</summary>

Shape: (1) derive the set of ids that are someone's parent. (2) Attach "am I in that set?" to every node without dropping or duplicating nodes. (3) Classify with one `CASE`, checking the no-parent case before the has-child case.

</details>

<details><summary>Hint 3</summary>

Key trick: `WITH parents AS (SELECT DISTINCT p_id FROM Tree WHERE p_id IS NOT NULL)`, then `Tree LEFT JOIN parents ON parents.p_id = Tree.id`, then `CASE WHEN t.p_id IS NULL THEN 'Root' WHEN parents.p_id IS NOT NULL THEN 'Inner' ELSE 'Leaf' END`. If you prefer a subquery, use `EXISTS`, or `IN`; never `NOT IN` over `p_id`, because the root's NULL is always in that list.

</details>

## 4. Decomposition

Translate each label into a question about rows. "No parent" is a question about *this* row (`p_id IS NULL`). "Has a child" is a question about *other* rows (is there a row whose `p_id` is my `id`?). The second kind of question is what needs a second read of the table.

1. **`parents`: `SELECT DISTINCT p_id FROM Tree WHERE p_id IS NOT NULL`.**
   *Why a second read of the table plus DISTINCT here:* "at least one child" is about other rows. Reading `Tree` as a list of `p_id`s answers it for every node at once. `DISTINCT` collapses k children to one row per parent, so the next join is 1:1. `WHERE p_id IS NOT NULL` drops the root's NULL, which never matches an id anyway; it keeps the set clean for anyone who later rewrites the check as `NOT IN`.
2. **`Tree LEFT JOIN parents ON parents.p_id = Tree.id`.**
   *Why a LEFT JOIN here:* every node must appear (output grain = `Tree`), and leaves by definition have no partner in `parents`. An inner join would delete every leaf.
3. **`CASE` in the order Root → Inner → Leaf.**
   *Why this order:* the labels overlap on the raw facts: the root usually has children. The spec resolves the overlap by precedence, and `CASE` implements precedence by branch order. `Leaf` is the `ELSE`, which is "has a parent and no child".

```sql
WITH parents AS (                              -- step 1: one row per node that has >= 1 child
  SELECT DISTINCT p_id
  FROM Tree
  WHERE p_id IS NOT NULL
)
SELECT t.id,                                   -- steps 2 + 3: every node, one row each
       CASE
         WHEN t.p_id IS NULL       THEN 'Root'   -- checked first: a root with children is still Root
         WHEN par.p_id IS NOT NULL THEN 'Inner'
         ELSE 'Leaf'
       END AS type
FROM Tree t
LEFT JOIN parents par ON par.p_id = t.id;
```

Self-check before you submit: exactly one `Root`, the row count equals `COUNT(*)` of `Tree`, and `COUNT(DISTINCT p_id)` (non-NULL) equals the number of `Inner` rows plus 1 if the root has children.

## 5. Approaches: brute force → optimal

### Approach 1: three queries, UNION ALL (`solutions/01_union_three_passes.sql`)

```sql
SELECT id, 'Root' AS type FROM Tree WHERE p_id IS NULL
UNION ALL
SELECT id, 'Inner' FROM Tree WHERE p_id IS NOT NULL AND id IN (SELECT p_id FROM Tree)
UNION ALL
SELECT id, 'Leaf'  FROM Tree WHERE p_id IS NOT NULL
                             AND id NOT IN (SELECT p_id FROM Tree WHERE p_id IS NOT NULL);
```

**Why it is correct:** the three `WHERE` clauses partition the nodes: no parent / parent and in the parent list / parent and not in it. Each node lands in exactly one branch. `IN` is safe with the NULL in its list (a match is TRUE; no match is UNKNOWN, which `WHERE` treats as false). The Leaf branch needs `WHERE p_id IS NOT NULL` inside its subquery; without it, `NOT IN` is never TRUE and the branch returns no rows.

This is the natural first attempt: the wording lists three labels, so you write three queries. It also has the most places for a NULL bug to hide.

**Cost model (reasoned, plan shape checked with `EXPLAIN FORMAT=TREE`):** three scans of `Tree` (one per branch) plus two subqueries that MySQL materialises as deduplicated temporary tables of `p_id` and probes by key. So the cost is linear, but every row is read about five times and two hash-deduplicated copies of `p_id` are built. With `indexes.sql` the `IN` branch is rewritten into a semijoin that reads `idx_tree_p_id` in order and skips duplicates, and the Root branch becomes one index lookup on `p_id IS NULL`.

### Approach 2: one CASE with a correlated EXISTS (`solutions/02_case_correlated_exists.sql`)

```sql
SELECT t.id,
       CASE WHEN t.p_id IS NULL THEN 'Root'
            WHEN EXISTS (SELECT 1 FROM Tree c WHERE c.p_id = t.id) THEN 'Inner'
            ELSE 'Leaf' END AS type
FROM Tree t;
```

**Why it is correct:** one pass over `Tree`, so each node appears exactly once. `EXISTS` is a semijoin: it stops at the first child, so a node with many children still gives one row. `EXISTS` returns only TRUE or FALSE, never UNKNOWN, so NULLs cannot leak in. This is the textbook answer, and the one to write in an interview *if you mention the index*.

**Cost model (reasoned, plan shape checked):** MySQL only rewrites subqueries in `WHERE` and `ON` into semijoins. A subquery in the **select list** stays a *dependent subquery*, run once per outer row. Without an index on `p_id`, each run scans `Tree` until it finds a child. An Inner node stops early. A **leaf scans the whole table**, and about half the nodes are leaves, so the cost grows with nodes² / 2. With `indexes.sql`, each run is one index probe on `p_id`, and the whole query becomes roughly linear. This approach has the largest gap between "with index" and "without index" of the three; see the two tables below.

### Approach 3 (optimal): LEFT JOIN to the distinct parent set (`solutions/03_left_join_parent_set.sql`)

The SQL is the assembled query in section 4.

**Why it is correct:** `parents` has at most one row per id, so the LEFT JOIN neither duplicates nodes (DISTINCT) nor drops them (LEFT). `par.p_id IS NOT NULL` is exactly "has at least one child". The CASE order resolves the root.

**Cost model (reasoned, plan shape checked):** one scan builds the deduplicated parent set. MySQL materialises it once and gives it an automatic key (`<auto_key0>`). A second scan of `Tree` probes that key. That is two linear passes and one temporary table of at most (nodes − leaves) rows. It needs no index: with `indexes.sql`, the `DISTINCT` becomes a "Group (no aggregates)" read off `idx_tree_p_id` in order instead of a hashed temporary table, which is a smaller win.

**Measured** (`gen.py` data, generated by the bench workflow; the table is filled in automatically, so never type numbers here):

<!-- BENCH:39-tree-node -->
_Measured 2026-11-04 by the bench workflow: MySQL 8.0.46, AMD EPYC 7763 64-Core Processor, 2 vCPU. Median of 3 runs after 1 warm-up; each statement capped at 60 s. Sizes are main-table rows from `gen.py`. Raw numbers and EXPLAIN ANALYZE: `bench/results/39-tree-node.json`._

**Without indexes**

| Solution | 1,000 rows | 100,000 rows | 1,000,000 rows | × slower than optimal @ 1,000,000 |
|---|---:|---:|---:|---:|
| `01_union_three_passes` | 7.52 ms | 630 ms | 10.2 s | 1.2× |
| `02_case_correlated_exists` | 112 ms | timeout >60s | timeout >60s † | > 7× |
| `03_left_join_parent_set` (optimal) | 6.46 ms | 596 ms | 8.43 s | 1.0× |

† not run at this size: it already timed out at a smaller size.

**With `indexes.sql`**

| Solution | 1,000 rows | 100,000 rows | 1,000,000 rows | × slower than optimal @ 1,000,000 |
|---|---:|---:|---:|---:|
| `01_union_three_passes` | 6.98 ms | 619 ms | 8.4 s | 1.1× |
| `02_case_correlated_exists` | 7.06 ms | 672 ms | 7.22 s | 0.9× |
| `03_left_join_parent_set` (optimal) | 6.71 ms | 584 ms | 7.74 s | 1.0× |

A ratio below 1.0× means that approach was faster than the one labelled optimal here.

> GitHub-hosted runners are shared, noisy VMs: compare the ratios between rows, not the absolute times.
<!-- /BENCH -->

### Why the optimal one wins

Approach 3 answers "has a child?" for all nodes at once, with one deduplicated set built in a single pass. Approach 2 asks the same question once per node. That is fine with an index on `p_id` and quadratic without one, so its speed depends on physical design the problem does not give you. Approach 1 is linear too, but reads the table about five times and has two NULL-sensitive subqueries. Approach 3 is also the shape that carries to distributed engines (section 6c): one aggregation and one equi-join, with no per-row subquery to decorrelate.

## 6. At scale

**(a) What breaks first.** *Reasoned, then checked by the bench table:* approach 2 without an index goes first, because each leaf rescans the whole table (nodes² growth). Approaches 1 and 3 are linear. Approach 1 reads more rows, so it falls behind next. Approach 3's temporary parent set is the last thing to outgrow memory (`tmp_table_size`), because it holds only non-leaf ids.

**(b) One machine, ~1M–100M rows.**
- `indexes.sql` adds `Tree (p_id)`. It is the index any self-referencing hierarchy needs: it turns "children of X" into a range read. For approach 2 it is the difference between quadratic and linear. For approach 3 it lets `DISTINCT p_id` stream off the index in order instead of hashing. The bench runs every approach with and without it.
- `(p_id)` on InnoDB is a secondary index whose entries also carry the PK `id`, so `(p_id)` alone is covering for these queries. You do not need `(p_id, id)`.
- If the tree is read far more than it is written, store the label (or a child count) in the table and maintain it on write; see (d).

**(c) Distributed engines, billions of rows. *Reasoned, not measured.***
- *Shuffle:* approach 3 is an aggregation (`DISTINCT p_id`) plus an equi-join on `id = p_id`. In Spark-style engines the `DISTINCT` pre-aggregates per task, then shuffles by `p_id`; the join shuffles `Tree` by `id` to meet it. Neither side is small enough to broadcast (non-leaves are often about half the nodes), so expect two shuffles of the node count.
- *One-shuffle rewrite:* unpivot each row into "I exist" and "my parent has a child", then group once:
  ```sql
  SELECT node AS id,
         CASE WHEN MAX(is_root) = 1 THEN 'Root' WHEN MAX(has_child) = 1 THEN 'Inner' ELSE 'Leaf' END AS type
  FROM (SELECT id AS node, IF(p_id IS NULL, 1, 0) AS is_root, 0 AS has_child, 1 AS exists_flag FROM Tree
        UNION ALL
        SELECT p_id, 0, 1, 0 FROM Tree WHERE p_id IS NOT NULL) x
  GROUP BY node
  HAVING MAX(exists_flag) = 1;     -- a p_id with no row of its own (an orphan reference) must not become a node
  ```
  That is one shuffle by node instead of two, the same "unpivot edges, then aggregate" move as `40-friend-requests-ii-who-has-the-most-friends`. It passes this problem's edge and differential tests on MySQL (checked once, not kept as a solution), but it sorts or hashes twice as many rows. Whether it beats the join depends on the engine.
- *Skew:* a hub node with millions of children (a top-level category) puts all its `p_id` rows on one reducer before deduplication. Local pre-aggregation (each task emits the hub once) removes that skew, which is another reason to deduplicate before joining.
- *Things to avoid:* no `ORDER BY` is required ("any order"), so don't add one. A correlated `EXISTS` in the select list relies on the engine to decorrelate it into a semijoin. Some do and some refuse it; the join form never depends on that.

**(d) The data-engineering answer.** Labels change only when edges change, and each new edge changes at most two labels: the new node is a Leaf (or Root), and its parent becomes Inner unless it is the root. Maintain a child count instead of recomputing:

```sql
-- node_stats(id PRIMARY KEY, p_id, n_children), fed by each batch of new nodes (new_nodes).
-- Snowflake / ANSI MERGE (UNVERIFIED): first insert the new nodes, then bump their parents.
MERGE INTO node_stats t
USING (SELECT p_id AS id, COUNT(*) AS n FROM new_nodes WHERE p_id IS NOT NULL GROUP BY p_id) s
ON t.id = s.id
WHEN MATCHED THEN UPDATE SET n_children = t.n_children + s.n;

-- MySQL equivalent:
INSERT INTO node_stats (id, p_id, n_children) SELECT id, p_id, 0 FROM new_nodes;
INSERT INTO node_stats (id, n_children)
SELECT p_id, COUNT(*) FROM new_nodes WHERE p_id IS NOT NULL GROUP BY p_id
ON DUPLICATE KEY UPDATE n_children = n_children + VALUES(n_children);

-- The label is then a per-row expression, no self-join:
SELECT id, CASE WHEN p_id IS NULL THEN 'Root' WHEN n_children > 0 THEN 'Inner' ELSE 'Leaf' END AS type
FROM node_stats;
```

Caveats interviewers probe. A *re-parent* (node moves) is −1 on the old parent and +1 on the new one, so you need the before image from CDC. A *delete* of a leaf is −1 on its parent. Deleting an inner node is a business decision (orphan the children, or re-parent them), not a SQL one. *Idempotency:* replaying a batch double-counts, so key batches by a watermark.

## 7. Edge cases

Each "breaks" claim below is checked by execution: `mistakes/*.sql` are the tempting wrong queries, and the harness asserts that each one fails every dataset it names (`harness/test_mistakes.py`).

| Case | Dataset | Wrong queries it catches (`mistakes/`) |
|---|---|---|
| Root with children, a node with exactly one child, children with smaller ids than their parent, rows inserted children-first | `tests/edge_typical.sql` | `not_in_with_null` (every leaf becomes Inner), `inner_checked_before_root` (root becomes Inner), `join_children_fanout` (20 and 30 appear twice) |
| NULL in the parent list: the root's `p_id` is NULL in every valid tree | every dataset with a leaf: `edge_typical`, `edge_chain`, `edge_star` | `not_in_with_null`: `id NOT IN (…, NULL)` is never TRUE, so the Leaf branch never fires |
| One-node tree: no parent and no children | `tests/edge_lone_root.sql` | `leaf_checked_before_root` (the lone root becomes Leaf). It passes every other dataset, because in any tree with an edge the root has a child. |
| Chain: every node has exactly one child | `tests/edge_chain.sql` | `inner_checked_before_root`, `not_in_with_null`. Note `join_children_fanout` **passes** here (no node has two children), so a chain-only test would miss the fan-out bug. |
| Star: one root, many leaf children | `tests/edge_star.sql` | `join_children_fanout` (root appears 4 times), `inner_checked_before_root`, `not_in_with_null` |
| Empty table | `tests/edge_empty.sql` | none in `mistakes/`. Every approach returns zero rows; it guards against a Root row produced by an aggregate (an aggregate without GROUP BY always returns one row). |

No approach in `solutions/` is broken by any of these. Approach 2 is slow without an index, not wrong.

## 8. Interviewer follow-ups

1. **"Also return each node's depth."** Now you need a path from the root, which has unbounded length, so use `WITH RECURSIVE`. Anchor: the root at depth 1. Step: join children on `c.p_id = parent.id`, depth + 1. Same shape as `43-analyze-organization-hierarchy`.
2. **"Return the number of children instead of a label."** Pre-aggregate `SELECT p_id, COUNT(*) FROM Tree GROUP BY p_id`, LEFT JOIN it, and `COALESCE(n, 0)`. Same as approach 3 with `COUNT` instead of `DISTINCT`, and the same "aggregate before join" shape as `01-market-analysis-i`.
3. **"The data might not be a valid tree. How do you detect it?"** Several roots: `COUNT(*) WHERE p_id IS NULL` ≠ 1. Orphans: `p_id` with no matching `id` (an anti-join, `NOT EXISTS`). Cycles: nodes never reached by a recursive walk from the root(s). That walk needs a depth cap or a visited path, because a recursive CTE over a cycle never terminates on its own (MySQL stops it at `cte_max_recursion_depth`, default 1000, with an error).
4. **"Why did your NOT IN return no leaves?"** Because the root's NULL is in the list. `x NOT IN (a, b, NULL)` means `x <> a AND x <> b AND x <> NULL`, and the last term is UNKNOWN. Use `NOT EXISTS`, or filter NULLs out of the subquery.
5. **"Single pass, no join?"** Use the unpivot-and-group rewrite from section 6c. It is one aggregation, and the `HAVING` clause guards against orphan references.

## 9. Snowflake notes (UNVERIFIED)

`snowflake.sql` keeps the shape of approach 3. What changes, and why:

- No indexes exist, so `indexes.sql` has no equivalent. The join version does not need one. Approach 2 depends on the engine decorrelating `EXISTS` inside a `CASE` in the select list. Snowflake restricts where correlated subqueries may appear, so approach 2 may fail to compile there. Check before relying on it.
- `IFF(cond, a, b)` is a shorter two-way `CASE`, but nested `IFF`s read worse than one three-branch `CASE` here.
- Snowflake has `CONNECT BY` for hierarchies (with `LEVEL` and `SYS_CONNECT_BY_PATH`). It is not needed for this problem, which only looks one hop away, but it is the natural tool for the depth follow-up.
- The `DISTINCT` in the CTE may be merged by the optimizer into a semijoin. Either way, writing it states the 1:1 intent.

## 10. Pattern links

Same data shape (self-referencing parent pointer), different depth of question:
- `41-find-the-downward-recommendation-chain-for-member-id-1`: walk **down** an unbounded number of hops, so recursion is needed.
- `42-produce-a-cte-that-can-return-the-upward-recommendation-chain-for-any-member`: walk **up** from every node, carrying the start node (a closure table).
- `43-analyze-organization-hierarchy`: depth plus subtree aggregates over the closure table.

Same existence-check skill (does another row exist that points at me?):
- `03-investments-in-2016`: existence of "another row with the same X", using EXISTS or a window count.
- `01-market-analysis-i`: `NOT IN` against a list containing NULL, the same trap.
- `40-friend-requests-ii-who-has-the-most-friends`: unpivot each edge into one row per endpoint, then aggregate (the one-shuffle rewrite in section 6c).
