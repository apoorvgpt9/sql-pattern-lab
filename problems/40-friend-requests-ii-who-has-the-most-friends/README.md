# 40 · Friend Requests II: Who Has the Most Friends

## 1. Problem & trigger phrases

Original: [Friend Requests II: Who Has the Most Friends](https://leetcode.com/problems/friend-requests-ii-who-has-the-most-friends/) (LeetCode 602, medium). Read the statement there; this guide only restates the spec in its own words.

**Spec (own words):** each row is one accepted friendship between a requester and an accepter. Return the single person with the most friends, counting friendships in which they were either the requester or the accepter, together with that count. The data guarantees exactly one such person.

| Trigger phrase | What it forces in SQL |
|---|---|
| "people who have the most friends" | Friendship is **symmetric**, but the table stores it in two differently named columns. A person's friends are spread over both columns, so you must count both: stack the two columns into one (`requester_id UNION ALL accepter_id`), then group. **ALL** matters. Plain `UNION` deduplicates, which turns "one row per friendship endpoint" into "one row per person", and every count becomes 1. |
| "only one person has the most friends" | The tie-break is out of scope, so `ORDER BY num DESC LIMIT 1` is acceptable. Say out loud that this relies on the guarantee; the usual follow-up is "now return everyone tied for first" (section 8). |

Notice the shape: one row stores **one edge with two endpoints**. Any question about a node's edges ("how many friends", "who are X's friends") first needs the edge turned into two node-rows. That *unpivot the edge* step is the whole problem.

## 2. Schema & grain

| Table | One row means | Keys that matter here |
|---|---|---|
| `RequestAccepted` | one accepted friendship (an undirected edge stored with a direction) | PK `(requester_id, accepter_id)`; `accept_date` is irrelevant |

**Output grain:** one row, `(id, num)`, or no rows if the table is empty.

**Where the grain changes, twice:**
1. *Edge → endpoint.* Each friendship becomes two rows, `(requester_id)` and `(accepter_id)`. Row count doubles. This is the unpivot.
2. *Endpoint → person.* `GROUP BY id` collapses each person's endpoint rows into a count. Then `ORDER BY … LIMIT 1` takes that one row out of all the people.

The data guarantees make `COUNT(*)` equal "number of distinct friends". The PK forbids the same ordered pair twice, and the data never stores one friendship in both directions (`(a, b)` and `(b, a)`). If that second guarantee were broken, you would need `COUNT(DISTINCT friend_id)` over the unpivoted `(id, friend_id)` pairs instead (section 8).

The PK also makes both id columns `NOT NULL`, so this problem has no NULL cases. The tricky inputs are about *which column* the winner appears in.

## 3. Hint ladder

<details><summary>Hint 1</summary>

Pattern: **unpivot an edge list, then aggregate per node**. A friendship is one row with two people in it; a friend count is about one person at a time.

</details>

<details><summary>Hint 2</summary>

Shape: (1) turn each friendship into two rows, one per person in it. (2) Count rows per person. (3) Keep the person with the largest count.

</details>

<details><summary>Hint 3</summary>

Key clause: `SELECT requester_id AS id FROM RequestAccepted UNION ALL SELECT accepter_id FROM RequestAccepted`, then `GROUP BY id ORDER BY COUNT(*) DESC LIMIT 1`. It must be `UNION ALL`. A faster variant counts each column with its own `GROUP BY` first and then adds the two partial counts per person.

</details>

## 4. Decomposition

The wording names one thing to compute (friends per person) and one thing to pick (the maximum). The trap sits between the two: the table's columns are *roles*, but the question is about *people*, regardless of role.

1. **`endpoints`: `SELECT requester_id AS id … UNION ALL SELECT accepter_id …`.**
   *Why a UNION ALL here (not a JOIN, not a GROUP BY):* "most friends" ignores who sent the request, so both columns hold the same kind of thing: a person who has this friendship. Stacking them puts every person's friendships in one column. A self-join would pair friendships with each other, which answers a different question (friends of friends). `ALL` keeps one row per friendship endpoint; dedup would merge different friendships of the same person.
2. **`GROUP BY id`, `COUNT(*) AS num`.**
   *Why a GROUP BY here:* "most friends" compares people, so collapse to one row per person first. `COUNT(*)` is safe because, under the data guarantees, every endpoint row is a distinct friend.
3. **`ORDER BY num DESC LIMIT 1`.**
   *Why a sort + limit and not a filter:* "the one with the most" is a top-1. The spec guarantees no tie, so a positional pick is correct. With ties possible, switch to `WHERE num = (SELECT MAX(num) …)` or `RANK()` (section 8).

```sql
WITH endpoints AS (                       -- step 1: edge grain -> endpoint grain (2 rows per friendship)
  SELECT requester_id AS id FROM RequestAccepted
  UNION ALL
  SELECT accepter_id        FROM RequestAccepted
)
SELECT id, COUNT(*) AS num                -- step 2: endpoint grain -> person grain
FROM endpoints
GROUP BY id
ORDER BY num DESC                         -- step 3: top-1 (single winner guaranteed)
LIMIT 1;
```

Self-check: `SUM(num)` over all people (before the `LIMIT`) must equal `2 * COUNT(*)` of the table. Every friendship has exactly two endpoints.

The optimal solution (approach 3) is the same plan with step 2 split in two: count per column first, then add the two partial counts per person.

## 5. Approaches: brute force → optimal

### Approach 1: correlated count per person (`solutions/01_correlated_count_per_person.sql`)

```sql
WITH people AS (SELECT requester_id AS id FROM RequestAccepted
                UNION
                SELECT accepter_id FROM RequestAccepted)
SELECT p.id,
       (SELECT COUNT(*) FROM RequestAccepted r
         WHERE r.requester_id = p.id OR r.accepter_id = p.id) AS num
FROM people p
ORDER BY num DESC
LIMIT 1;
```

**Why it is correct:** `people` is the set of everyone who appears in either column, and here `UNION` (dedup) is exactly right, because it is a list of people. For each person, the subquery counts rows that mention them in either role. No row mentions the same person twice, so each row counts once. It is the natural first attempt because it mirrors the sentence "for each person, count their friendships".

**Cost model (reasoned, plan shape checked with `EXPLAIN FORMAT=TREE`):** the subquery sits in the select list, so MySQL runs it as a *dependent subquery* once per person. Without an index on `accepter_id`, the `OR` cannot use the primary key alone, so each run scans the whole table. The cost is people × rows, which is quadratic. With `indexes.sql`, the plan shows "Index range scan … re-planned for each iteration": each run probes the PK for `requester_id` and the new index for `accepter_id`, so the cost becomes roughly linear. A top-1 sort (`limit input to 1 row`) then keeps only the best row.

### Approach 2: UNION ALL, then GROUP BY (`solutions/02_union_all_then_group.sql`)

The SQL is the assembled query in section 4.

**Why it is correct:** every friendship contributes exactly one row to each of its two people, so the count per person is their number of friendships.

**Cost model (reasoned, plan shape checked):** two scans of the table feed a materialised union of **2 × rows** narrow rows. Then an *aggregate using temporary table* hashes all of them by `id`, and a top-1 pass picks the winner. It is linear and needs no index, but the hash aggregate sees every endpoint row. Once the temporary table outgrows `tmp_table_size`, it spills to disk. An index on `accepter_id` does not help much here, because the union is materialised before the grouping.

### Approach 3 (optimal): aggregate each role, then add (`solutions/03_aggregate_each_role_then_sum.sql`)

```sql
WITH per_role AS (
  SELECT requester_id AS id, COUNT(*) AS n FROM RequestAccepted GROUP BY requester_id
  UNION ALL
  SELECT accepter_id,        COUNT(*)      FROM RequestAccepted GROUP BY accepter_id
)
SELECT id, SUM(n) AS num
FROM per_role
GROUP BY id
ORDER BY num DESC
LIMIT 1;
```

**Why it is correct:** `COUNT` is decomposable. A person's total is (rows where they are the requester) + (rows where they are the accepter). Each branch produces at most one row per person, and the outer `SUM` adds the one or two partial counts. A person who appears in only one role has one partial row, and that is still counted. This is what the `inner_join_role_counts` mistake gets wrong.

**Cost model (reasoned, plan shape checked):** the requester branch is a *group aggregate* that streams off the primary key (PK order is `requester_id` first), with no temporary table. Without an index, the accepter branch needs one hashed temporary table. With `indexes.sql` it also streams, off `idx_ra_accepter`. The union then holds about 2 × people rows instead of 2 × friendship rows, so the final hash aggregate is smaller by the average friend count.

**Measured** (`gen.py` data, generated by the bench workflow; the table is filled in automatically, so never type numbers here):

<!-- BENCH:40-friend-requests-ii-who-has-the-most-friends -->
_Measured 2026-11-04 by the bench workflow: MySQL 8.0.46, AMD EPYC 7763 64-Core Processor, 2 vCPU. Median of 3 runs after 1 warm-up; each statement capped at 60 s. Sizes are main-table rows from `gen.py`. Raw numbers and EXPLAIN ANALYZE: `bench/results/40-friend-requests-ii-who-has-the-most-friends.json`._

**Without indexes**

| Solution | 1,000 rows | 100,000 rows | 1,000,000 rows | × slower than optimal @ 1,000,000 |
|---|---:|---:|---:|---:|
| `01_correlated_count_per_person` | 57.5 ms | timeout >60s | timeout >60s † | > 14× |
| `02_union_all_then_group` | 1.25 ms | 74.6 ms | 4.9 s | 1.2× |
| `03_aggregate_each_role_then_sum` (optimal) | 1.32 ms | 80 ms | 4.18 s | 1.0× |

† not run at this size: it already timed out at a smaller size.

**With `indexes.sql`**

| Solution | 1,000 rows | 100,000 rows | 1,000,000 rows | × slower than optimal @ 1,000,000 |
|---|---:|---:|---:|---:|
| `01_correlated_count_per_person` | 59.2 ms | timeout >60s | timeout >60s † | > 33× |
| `02_union_all_then_group` | 1.98 ms | 76.1 ms | 5.33 s | 2.9× |
| `03_aggregate_each_role_then_sum` (optimal) | 1.12 ms | 57.1 ms | 1.82 s | 1.0× |

† not run at this size: it already timed out at a smaller size.

> GitHub-hosted runners are shared, noisy VMs: compare the ratios between rows, not the absolute times.
<!-- /BENCH -->

### Why the optimal one wins

Approach 3 does the heavy counting where the data is already ordered (the PK for requesters, the index for accepters). It hands the final aggregate one row per person per role instead of one row per friendship endpoint. Approach 2 has the same logic, but hashes every endpoint row. Approach 1 recounts the table once per person, so it is quadratic without the accepter index. The pre-aggregate-then-combine shape is also what keeps the shuffle small at scale (section 6c).

## 6. At scale

**(a) What breaks first.** *Reasoned, then checked by the bench table:* approach 1 without the index goes first, because people × rows grows quadratically. Approach 2's temporary table of 2 × rows endpoint ids comes next, once it no longer fits in memory and spills. Approach 3's temporary tables hold one row per person, so they are smaller by the average degree.

**(b) One machine, ~1M–100M rows.**
- `indexes.sql` adds `RequestAccepted (accepter_id)`. The PK already covers `requester_id`. With both, each role's `GROUP BY` streams in index order. The bench runs every approach with and without it.
- `ORDER BY num DESC LIMIT 1` is not a full sort: MySQL keeps a top-1 buffer (the plan shows `limit input to 1 row(s) per chunk`). The cost sits in the aggregation, not the sort.
- If this is a product query ("top users by friends"), don't recompute it. Keep a `friend_count` per user, maintained on write; see (d).

**(c) Distributed engines, billions of rows. *Reasoned, not measured.***
- *Shuffle:* approach 2 shuffles 2 × rows endpoint ids by `id`. Approach 3 pre-aggregates each role inside each task, so the shuffle carries at most one partial count per (person, role, task). With a skewed social graph, a few celebrities hold millions of edges, and pre-aggregation is the difference between one reducer receiving millions of rows and receiving one row per task.
- *Global top-1:* the final pick needs every person's total in one place. Engines do it as a two-stage top-k (a local top-1 per task, then a global top-1 of those), which is cheap. A full `ORDER BY` without `LIMIT` over billions of people would be a single-stage global sort, so never drop the `LIMIT`. Snowflake's `MAX_BY(id, num)` expresses the same thing as an aggregate.
- *Approximation:* for "top-k most connected" on a dashboard, sketch-based heavy-hitter functions (Snowflake `APPROX_TOP_K`) give the answer in one pass with bounded memory. For anything that pays out or ranks users publicly, use exact counts.
- *Graph engines:* degree is the one graph metric SQL computes well. Anything that walks paths (friends-of-friends, shortest path) becomes a recursive CTE or a graph engine; see `42-produce-a-cte-that-can-return-the-upward-recommendation-chain-for-any-member` and `43-analyze-organization-hierarchy`.

**(d) The data-engineering answer.** Friend count is an additive per-user counter. Each new friendship increments two users, and each unfriend decrements two:

```sql
-- user_degree(user_id PRIMARY KEY, num), fed by each batch of new friendships (new_edges).
-- Snowflake / ANSI MERGE (UNVERIFIED):
MERGE INTO user_degree t
USING (SELECT id, COUNT(*) AS n
       FROM (SELECT requester_id AS id FROM new_edges
             UNION ALL
             SELECT accepter_id FROM new_edges) e
       GROUP BY id) s
ON t.user_id = s.id
WHEN MATCHED THEN UPDATE SET num = t.num + s.n
WHEN NOT MATCHED THEN INSERT (user_id, num) VALUES (s.id, s.n);

-- MySQL equivalent:
INSERT INTO user_degree (user_id, num)
SELECT id, COUNT(*) FROM (SELECT requester_id AS id FROM new_edges
                          UNION ALL SELECT accepter_id FROM new_edges) e
GROUP BY id
ON DUPLICATE KEY UPDATE num = num + VALUES(num);

-- With an index on user_degree(num), the question becomes one index read: SELECT user_id, num FROM user_degree ORDER BY num DESC LIMIT 1;
```

Caveats interviewers probe. *Idempotency:* a replayed batch double-counts, so apply batches by watermark, or dedupe on the PK pair before merging. *Unfriend:* this needs the deleted pair from CDC to apply −1 to both ends. *A friendship stored in both directions* would double-count in both the batch query and the full recompute; normalise to `(LEAST(a,b), GREATEST(a,b))` on ingest.

## 7. Edge cases

Each "breaks" claim below is checked by execution: `mistakes/*.sql` are the tempting wrong queries, and the harness asserts that each one fails every dataset it names (`harness/test_mistakes.py`).

| Case | Dataset | Wrong queries it catches (`mistakes/`) |
|---|---|---|
| Winner appears in both roles; another user leads in one role | `tests/edge_typical.sql` | `union_dedups_people` (everyone counts 1), `requester_only` (picks user 1 with 3) |
| Winner only ever accepted | `tests/edge_accepter_only.sql` | `requester_only`, `inner_join_role_counts` (the winner has no requester row, so the inner join drops them) |
| Winner only ever requested | `tests/edge_requester_only.sql` | `inner_join_role_counts`. `requester_only` **passes** here by luck, which is why one-role datasets alone are not enough. |
| Three-way tie for second place, unique winner | `tests/edge_runner_up_ties.sql` | `union_dedups_people`, `requester_only` (right person, wrong count: 2). A tie below the top never affects `LIMIT 1`. |
| Empty table | `tests/edge_empty.sql` | none in `mistakes/`. Every approach returns no rows. An aggregate-only answer such as `SELECT MAX(...)` would return one NULL row; the Snowflake version guards against it with `HAVING COUNT(*) > 0`. |

There is no NULL dataset: the primary key makes both id columns `NOT NULL`. The single-winner guarantee is also why there is no dataset with a tie at the top. Under a tie, `LIMIT 1` may return either person, so no hand-computed expected row would be well-defined. `gen.py` builds its random data so that the winner is unique (see its docstring), which keeps the differential test meaningful.

No approach in `solutions/` is broken by any of these. Approach 1 is slow without the index, not wrong.

## 8. Interviewer follow-ups

1. **"Return everyone tied for the most."** Compute per-person counts in a CTE, then `WHERE num = (SELECT MAX(num) FROM counts)`. Or use `RANK() OVER (ORDER BY num DESC) = 1`. `DENSE_RANK` gives the same top group; the difference only shows up for "top 3".
2. **"What if the same friendship can appear as both (a, b) and (b, a)?"** Then `COUNT(*)` double-counts. Unpivot to `(id, friend_id)` pairs (`requester_id, accepter_id` UNION ALL `accepter_id, requester_id`), then `COUNT(DISTINCT friend_id)`. Or normalise each pair to `(LEAST, GREATEST)` and `SELECT DISTINCT` first.
3. **"Friend count per user, including users with zero friends (from a Users table)."** Pre-aggregate as in approach 3, then `Users LEFT JOIN counts` with `COALESCE(num, 0)`. Same shape as `01-market-analysis-i`.
4. **"Mutual friends of two users."** Unpivot to `(id, friend_id)`, then self-join on `friend_id` for the two given ids. That is a pairwise self-join, as in `12-find-product-recommendation-pairs`.
5. **"Why not FULL OUTER JOIN the two role counts?"** That is correct, and approach 3 is equivalent to it, but MySQL has no `FULL OUTER JOIN`. The usual MySQL emulation is `LEFT JOIN … UNION … RIGHT JOIN`, which is longer and easy to get wrong. `UNION ALL` + `SUM` is the outer join without the join.

## 9. Snowflake notes (UNVERIFIED)

`snowflake.sql` keeps approach 3's pre-aggregation. What changes, and why:

- `MAX_BY(id, num)` replaces `ORDER BY num DESC LIMIT 1`. It is an aggregate, so it runs as a two-stage local/global reduction instead of a sort. Among ties it returns an arbitrary one, which is acceptable only because the spec guarantees a single winner. `HAVING COUNT(*) > 0` keeps the result empty for an empty table: an aggregate without `GROUP BY` otherwise returns one row of NULLs.
- `FULL OUTER JOIN` exists in Snowflake, so `r FULL JOIN a ON r.id = a.id` with `COALESCE(r.n,0) + COALESCE(a.n,0)` is a valid alternative. `UNION ALL` + `SUM` is usually as cheap, and it does not need the `COALESCE` pair.
- No secondary indexes exist. The two `GROUP BY`s hash-aggregate in parallel. A clustering key would not help a full-table count.
- `QUALIFY RANK() OVER (ORDER BY num DESC) = 1` is the concise all-ties version of follow-up 1.

## 10. Pattern links

Same unpivot-the-edge move:
- `39-tree-node`: the one-shuffle rewrite (section 6c there) unpivots each parent pointer into "I exist" and "my parent has a child".
- `09-count-salary-categories`: UNION ALL of separate pieces to build one result column.

Same "count per key, then pick the top" shape:
- `16-department-highest-salary`, `19-department-top-three-salaries`: top-k per group with explicit tie rules, which is follow-up 1 with a `PARTITION BY`.

Same aggregate-before-combine idea:
- `01-market-analysis-i`: pre-aggregate the big table, then join.
- `12-find-product-recommendation-pairs`: the pairwise self-join that follow-up 4 needs.
