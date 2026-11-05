# 43 · Analyze Organization Hierarchy

## 1. Problem & trigger phrases

Original: [Analyze Organization Hierarchy](https://leetcode.com/problems/analyze-organization-hierarchy/) (LeetCode 3482, hard). Read the statement there; this guide only restates the spec in its own words.

**Spec (own words):** an employee table with a manager pointer forms one org tree under a single CEO. For every employee, report three numbers. *Level*: the CEO is 1, and each step down adds 1. *Team size*: how many people sit anywhere below them, directly or indirectly (0 for individual contributors). *Budget*: their own salary plus the salaries of everyone below them. Sort by level ascending, then budget descending, then name ascending.

| Trigger phrase | What it forces in SQL |
|---|---|
| "CEO is level 1" | Level is the distance from the root, counted from 1. Either recurse down from the CEO (`manager_id IS NULL`) with `1` in the anchor and `+1` per step, or count each employee's ancestors and add 1. Anchoring at 0 is the classic off-by-one. |
| "direct and indirect reports" | One self-join gives direct reports only. You need every (manager, report) pair at any distance, a **closure table**, built with `WITH RECURSIVE`. |
| "plus their own salary" | Budget = own salary + the sum over the closure. For an individual contributor the closure is empty, `SUM` over nothing is NULL, and `salary + NULL` is NULL, so `COALESCE` the sum to 0 *before* adding. |
| "ordered by level ... budget ... employee_name" | Three sort keys, two of them ascending and one descending: `ORDER BY level ASC, budget DESC, employee_name ASC`. Every key is a computed column, so sort in the outer query, after all three are known. |

## 2. Schema & grain

| Table | One row means | Keys that matter here |
|---|---|---|
| `Employees` | one employee, with a pointer to their manager | `employee_id` (PK); `manager_id` (NULL only for the CEO); `salary`; `employee_name` for output and the last sort key. `department` is not needed. |

**Output grain:** one row per employee, **including** individual contributors (team size 0, budget = own salary). Row count = `COUNT(*)` of `Employees`.

**Where the grain changes:** this is the problem's real difficulty. Two of the three metrics are *subtree aggregates*: they live at the grain "one manager, summed over everyone below". The table only stores one hop.

1. **Employee → (manager, report) pairs.** The closure fans out. An employee at level d appears as a report under d − 1 managers, so the closure has (sum of all depths) rows: several times the table.
2. **Pairs → manager.** `GROUP BY manager` collapses the closure back to one row per manager, giving `COUNT` (team size) and `SUM(salary)` (team salary).
3. **Back to employee.** `LEFT JOIN` those aggregates to every employee. Non-managers have no group, so `COALESCE` gives 0.

Level is a third, separate grain question: one number per employee from the depth of the path. You get it either from a second recursion down from the CEO (approaches 1, 2), or by counting the same closure grouped the other way, per report (approach 3).

## 3. Hint ladder

<details><summary>Hint 1</summary>

Pattern: **closure table + subtree aggregation**. A recursive CTE that pairs each employee with everyone above (or below) them, then plain `GROUP BY`s on those pairs.

</details>

<details><summary>Hint 2</summary>

Shape: (1) build every (manager, report) pair at any distance. (2) Per manager: count the pairs, and sum the reports' salaries. (3) Per employee: level from their position in the tree. (4) Attach everything to every employee, with zeros for non-managers, and sort.

</details>

<details><summary>Hint 3</summary>

Key trick: walk **up** from every employee and *carry their salary*: `chain(employee_id, salary, ancestor)`, anchor `(employee_id, salary, manager_id)`, step `JOIN Employees m ON m.employee_id = c.ancestor`, emitting `m.manager_id`. Then `GROUP BY ancestor` gives team size and team salary. `GROUP BY employee_id` gives the number of people above, so level = that count + 1. One recursion answers all three metrics, and climbing uses only primary-key lookups.

</details>

## 4. Decomposition

Each metric's wording tells you which side of the closure to group on. "Reports" and "budget" are about the people *below* someone, so group the pairs by the manager. "Level" is about the people *above* someone, so group by the report. Notice that both are the same set of pairs, read two ways. That is why one closure is enough.

1. **`chain`: every (employee, ancestor) pair, carrying the employee's salary.**
   *Why a recursive CTE here:* "direct and indirect" means arbitrary depth. *Why walk up (anchor = each employee's manager, step = manager's manager):* following the stored pointer is a primary-key lookup per step, so no secondary index is needed. *Why carry `salary`:* the budget needs the *report's* salary attached to every pair. Carrying it avoids joining `Employees` again later.
2. **`as_manager`: `GROUP BY ancestor` → `COUNT(*)`, `SUM(salary)`.**
   *Why a GROUP BY here:* team size and budget are per manager, summed over the subtree. Each pair with `ancestor = X` is one person under X.
3. **`as_report`: `GROUP BY employee_id` → `COUNT(*)` = people above.**
   *Why a GROUP BY here:* level − 1 is the number of ancestors, which is the number of pairs where this employee is the report. No second recursion is needed.
4. **Final: `Employees LEFT JOIN as_manager LEFT JOIN as_report`, then `COALESCE` and sort.**
   *Why LEFT JOINs:* every employee appears. The CEO has no `as_report` row (nobody above), so level = 1 + 0. Individual contributors have no `as_manager` row, so team size = 0 and budget = salary + 0.

```sql
WITH RECURSIVE chain (employee_id, salary, ancestor) AS (
  SELECT employee_id, salary, manager_id         -- step 1 anchor: each employee + direct manager
  FROM Employees
  WHERE manager_id IS NOT NULL                   -- the CEO has no ancestor
  UNION ALL
  SELECT c.employee_id, c.salary, m.manager_id   -- step 1: one hop up (PK lookup), salary carried
  FROM chain c
  JOIN Employees m ON m.employee_id = c.ancestor
  WHERE m.manager_id IS NOT NULL                 -- stop below the top: no NULL ancestor
),
as_manager AS (                                  -- step 2: everyone below each manager
  SELECT ancestor AS employee_id, COUNT(*) AS team_size, SUM(salary) AS team_salary
  FROM chain GROUP BY ancestor
),
as_report AS (                                   -- step 3: everyone above each employee
  SELECT employee_id, COUNT(*) AS n_above
  FROM chain GROUP BY employee_id
)
SELECT e.employee_id, e.employee_name,           -- step 4: every employee, zeros filled in
       1 + COALESCE(r.n_above, 0)            AS level,
       COALESCE(m.team_size, 0)              AS team_size,
       e.salary + COALESCE(m.team_salary, 0) AS budget
FROM Employees e
LEFT JOIN as_manager m ON m.employee_id = e.employee_id
LEFT JOIN as_report  r ON r.employee_id = e.employee_id
ORDER BY level ASC, budget DESC, e.employee_name ASC;
```

Self-check: the CEO's team size is `COUNT(*) − 1`. The CEO's budget is `SUM(salary)` of the whole table. Each manager's budget equals their salary plus their direct reports' budgets, a recursive identity you can spot-check by hand.

## 5. Approaches: brute force → optimal

### Approach 1: two recursions + correlated subqueries (`solutions/01_closure_correlated_subqueries.sql`)

```sql
WITH RECURSIVE
levels (employee_id, level) AS (               -- down from the CEO
  SELECT employee_id, 1 FROM Employees WHERE manager_id IS NULL
  UNION ALL
  SELECT e.employee_id, l.level + 1 FROM Employees e JOIN levels l ON e.manager_id = l.employee_id
),
reports (manager_id, report_id) AS (           -- down from every manager
  SELECT manager_id, employee_id FROM Employees WHERE manager_id IS NOT NULL
  UNION ALL
  SELECT r.manager_id, e.employee_id FROM reports r JOIN Employees e ON e.manager_id = r.report_id
)
SELECT e.employee_id, e.employee_name, l.level,
       (SELECT COUNT(*) FROM reports r WHERE r.manager_id = e.employee_id) AS team_size,
       e.salary + (SELECT COALESCE(SUM(s.salary), 0) FROM reports r
                   JOIN Employees s ON s.employee_id = r.report_id
                   WHERE r.manager_id = e.employee_id) AS budget
FROM Employees e JOIN levels l ON l.employee_id = e.employee_id
ORDER BY l.level ASC, budget DESC, e.employee_name ASC;
```

**Why it is correct:** `levels` assigns each employee their distance from the CEO, plus 1. `reports` holds every (manager, report) pair: the anchor gives distance 1, and each step extends a pair one level down. A scalar `COUNT` over no rows is 0, and the budget subquery `COALESCE`s its `SUM`. It reads exactly like the spec, one employee and one metric at a time, which makes it the natural first attempt.

**Cost model (reasoned, plan shape checked with `EXPLAIN FORMAT=TREE`):** two recursions, both walking **down**. Without an index on `manager_id`, every iteration of each is a hash join that scans all of `Employees` once, so the cost is (org depth) × (table size) per recursion. The closure `reports` is materialised once (sum of depths rows). MySQL then gives it an automatic key (`<auto_key0>` on `manager_id`), so each correlated subquery is an index lookup into it, not a rescan. The quadratic blow-up you might expect does not happen. The cost lies elsewhere: two subqueries per employee, the budget one with a PK lookup per pair, so the closure is read twice and joined to `Employees` once per pair. With `indexes.sql`, both recursions' steps become index lookups on `manager_id`.

### Approach 2: two recursions + GROUP BY (`solutions/02_closure_group_by.sql`)

Same `levels` and `reports` CTEs, then:

```sql
team AS (SELECT r.manager_id, COUNT(*) AS team_size, SUM(s.salary) AS team_salary
         FROM reports r JOIN Employees s ON s.employee_id = r.report_id
         GROUP BY r.manager_id)
SELECT e.employee_id, e.employee_name, l.level,
       COALESCE(t.team_size, 0) AS team_size, e.salary + COALESCE(t.team_salary, 0) AS budget
FROM Employees e JOIN levels l ON l.employee_id = e.employee_id
LEFT JOIN team t ON t.manager_id = e.employee_id
ORDER BY l.level ASC, budget DESC, e.employee_name ASC;
```

**Why it is correct:** the same closure, aggregated once per manager instead of queried once per employee. The `LEFT JOIN` + `COALESCE` gives individual contributors 0.

**Cost model (reasoned, plan shape checked):** both recursions are as in approach 1. The closure is read once, with a PK lookup per pair for the salary, into one temp-table aggregate. That is one pass instead of two correlated passes. The downward walks still need `indexes.sql` to avoid one full scan per org level.

### Approach 3 (optimal): one upward closure carrying salary (`solutions/03_upward_closure_carry_salary.sql`)

The SQL is the assembled query in section 4.

**Why it is correct:** for each employee E, `chain` holds exactly one row per ancestor of E, and each row carries E's salary. So for a manager M, the rows with `ancestor = M` are exactly M's direct and indirect reports. Their count is the team size, and their salary sum is the team salary. For an employee E, the rows with `employee_id = E` number E's ancestors, which is level − 1. In a single-CEO tree that ancestor count is the distance to the CEO.

**Cost model (reasoned, plan shape checked):** **one** recursion instead of two, walking **up**. Each step is a single-row primary-key lookup, so there are no full scans per level and no secondary index is needed (`indexes.sql` should change little here; the bench measures it). The salary rides along in the closure, so no per-pair join back to `Employees` is needed. MySQL materialises `chain` once and runs two hash aggregates over it, then two auto-key lookups per employee. The closure size (sum of depths) is the same in every approach. Approach 3 builds it once, with the cheapest possible step, and reads it twice without joins.

**Measured** (`gen.py` data, generated by the bench workflow; the table is filled in automatically, so never type numbers here):

<!-- BENCH:43-analyze-organization-hierarchy -->
_Measured 2026-11-05 by the bench workflow: MySQL 8.0.46, AMD EPYC 9V45 96-Core Processor, 2 vCPU. Median of 3 runs after 1 warm-up; each statement capped at 60 s. Sizes are main-table rows from `gen.py`. Raw numbers and EXPLAIN ANALYZE: `bench/results/43-analyze-organization-hierarchy.json`._

**Without indexes**

| Solution | 1,000 rows | 100,000 rows | × slower than optimal @ 100,000 |
|---|---:|---:|---:|
| `01_closure_correlated_subqueries` | 11.3 ms | 3.67 s | 2.8× |
| `02_closure_group_by` | 9.92 ms | 1.94 s | 1.5× |
| `03_upward_closure_carry_salary` (optimal) | 8.08 ms | 1.3 s | 1.0× |

**With `indexes.sql`**

| Solution | 1,000 rows | 100,000 rows | × slower than optimal @ 100,000 |
|---|---:|---:|---:|
| `01_closure_correlated_subqueries` | 12.1 ms | 3.47 s | 2.8× |
| `02_closure_group_by` | 10.8 ms | 1.88 s | 1.5× |
| `03_upward_closure_carry_salary` (optimal) | 7.6 ms | 1.26 s | 1.0× |

> GitHub-hosted runners are shared, noisy VMs: compare the ratios between rows, not the absolute times.
<!-- /BENCH -->

### Why the optimal one wins

All three approaches pay for the closure: there is no way around touching every (manager, report) pair. They differ in how they build and read it. Approaches 1 and 2 walk down, so each level needs an index on `manager_id` or it is a full scan. They also walk twice (levels and closure), and they look up each report's salary per pair. Approach 3 walks up the primary key once, carries the salary, and gets level from the same rows. It is the only version whose speed does not depend on an index the problem does not mention.

## 6. At scale

**(a) What breaks first.** *Reasoned, then checked by the bench table:* without `indexes.sql`, approaches 1 and 2 pay (org depth) × (table size) for *each* of their two downward recursions. At 1M employees with `gen.py`'s depth (max ~23), that is dozens of full scans. Approach 1 also does two lookups per employee into an ~8M-row closure. Approach 3's limit is the closure itself: `gen.py`'s average depth of about 9 at 1M rows makes it ~8.4M narrow rows in one temporary table, which spills past `tmp_table_size`.

**(b) One machine, ~1M–100M rows.**
- `indexes.sql` adds `Employees (manager_id)`. Downward traversals (approaches 1, 2, and any "who reports to X" query) need it. Upward traversals (approach 3) don't. The bench runs every approach with and without it, which makes the direction lesson from `42-produce-a-cte-that-can-return-the-upward-recommendation-chain-for-any-member` measurable.
- The closure is unavoidable (O(sum of depths)) if you recompute from scratch. A **bottom-up rollup** avoids it: process levels from the deepest up, and set each manager's budget = salary + SUM(direct reports' budgets). That is depth passes over the table with only direct-report joins, O(table × depth) work but O(table) space. MySQL has no loop in a single query; it would be a stored procedure or an orchestrated job.
- Raise `tmp_table_size`/`max_heap_table_size` for the session if the closure spills, or accept the spill. It is sequential I/O.

**(c) Distributed engines, billions of rows. *Reasoned, not measured.***
- *Closure explosion:* sum of depths × rows is the size of the work. Org charts are shallow (depth ~10), so 10× the table. Bills of materials or deep graphs make this the dominant cost; there, the bottom-up rollup (one join per level, each touching only direct edges) is the scalable pattern. Spark/GraphFrames-style "aggregate messages" do exactly that.
- *Shuffle per iteration:* each recursion level is a join of the frontier with `Employees` on the key being followed, one shuffle per level, unless `Employees` (or the frontier) is broadcast. Upward walking keys on `employee_id`, so `Employees` can stay partitioned by its PK and only the frontier moves.
- *Skew:* the CEO is the ancestor of every row, so `GROUP BY ancestor` sends the whole table's worth of pairs to one key. `COUNT` and `SUM` are decomposable, so partial aggregation per task makes this harmless. A non-decomposable metric (a median salary per subtree) would not be; that is a reason to prefer approximate quantile sketches there.
- *Global sort:* the output order is a total sort of every employee, a single-stage bottleneck. If the consumer only needs, say, the top budgets per level, use a window `ROW_NUMBER() OVER (PARTITION BY level ORDER BY budget DESC)` and filter, which sorts within partitions only.

**(d) The data-engineering answer.** Org data changes slowly, and is read often. Keep the closure as a table and maintain the subtree aggregates incrementally:

```sql
-- emp_closure(ancestor, employee_id, PRIMARY KEY (ancestor, employee_id)); emp_stats(employee_id PK, team_size, team_salary).
-- New hire h with manager m (batch: new_hires): ancestors(h) = m + ancestors(m).
-- Snowflake / ANSI MERGE (UNVERIFIED):
MERGE INTO emp_stats t
USING (
  SELECT a.ancestor AS employee_id, COUNT(*) AS n, SUM(h.salary) AS s
  FROM new_hires h
  JOIN (SELECT employee_id, ancestor FROM emp_closure
        UNION ALL
        SELECT employee_id, employee_id FROM emp_stats) a      -- the manager themself
    ON a.employee_id = h.manager_id
  GROUP BY a.ancestor
) d
ON t.employee_id = d.employee_id
WHEN MATCHED THEN UPDATE SET team_size = t.team_size + d.n, team_salary = t.team_salary + d.s;
-- ...then INSERT the new hires' own closure rows and a zero emp_stats row each.
-- MySQL: the same aggregate as INSERT ... ON DUPLICATE KEY UPDATE team_size = team_size + VALUES(team_size), ...
```

Caveats interviewers probe. *Salary changes* are a delta on every ancestor's `team_salary`: one row per ancestor, cheap with the closure. *Re-orgs* (a manager moves with their team) change the ancestors of a whole subtree. Subtract the subtree's totals from the old ancestors, add them to the new ones, and rewrite the closure rows. *Level* changes for the whole moved subtree too. *Idempotency:* apply each batch once, by watermark.

## 7. Edge cases

Each "breaks" claim below is checked by execution: `mistakes/*.sql` are the tempting wrong queries, and the harness asserts that each one fails every dataset it names (`harness/test_mistakes.py`).

| Case | Dataset | Wrong queries it catches (`mistakes/`) |
|---|---|---|
| Four levels, a manager with one indirect report, budgets 390 vs 380 at level 2 | `tests/edge_typical.sql` | `direct_reports_only`, `count_star_after_left_join` (individual contributors get 1), `budget_null_for_leaves`, `level_starts_at_zero`, `sort_without_budget` |
| A company of one | `tests/edge_lone_ceo.sql` | `count_star_after_left_join` (CEO team size 1), `budget_null_for_leaves` (NULL budget), `level_starts_at_zero` |
| Six-level chain: one direct report each, up to five in total | `tests/edge_deep_chain.sql` | `direct_reports_only` (every team size 1), and the three NULL/zero/level mistakes |
| Ordering: level beats budget, budget beats name, exact budget tie broken by name; rows shuffled | `tests/edge_order.sql` | `sort_without_budget` (Pat, budget 450, must precede Lou and Mia at 100), `direct_reports_only` |
| Flat org: four direct reports, three equal salaries | `tests/edge_star.sql` | `sort_without_budget`, `count_star_after_left_join`, `budget_null_for_leaves`, `level_starts_at_zero`. `direct_reports_only` **passes** here: in a flat org, direct = all. |

NULLs: `manager_id` is NULL only for the CEO. The "nulls" the spec warns about are *produced* NULLs: a missing aggregate row for a non-manager. `COALESCE` must wrap the team aggregates before any arithmetic (`budget_null_for_leaves`), and the count must count a column that is NULL for no match (`count_star_after_left_join`). Ties: the spec fixes the full order. Every edge dataset avoids rows that tie on all three keys, because their order would be undefined.

No approach in `solutions/` is broken by any of these.

## 8. Interviewer follow-ups

1. **"Only count reports in the same department as the manager."** Carry the report's `department` in the closure (approach 3 carries `salary` the same way), join the ancestor's department, and use `SUM(CASE WHEN same_dept THEN 1 END)`. Conditional aggregation over the closure, as in `04-monthly-transactions-i`.
2. **"Highest budget per level only."** Wrap the result in `RANK() OVER (PARTITION BY level ORDER BY budget DESC)` and keep rank 1. `RANK` keeps ties, `ROW_NUMBER` picks one. Same pattern as `16-department-highest-salary`.
3. **"There might be several CEOs (a forest)."** Approach 3 works unchanged: level = ancestors + 1 per tree. Approaches 1 and 2 also work, since `levels` anchors on every `manager_id IS NULL`. Only the self-check "CEO budget = total payroll" changes, to "per root".
4. **"What if someone's manager_id points to a non-existent employee?"** Upward walk: the chain stops at the dangling id, and that id becomes an ancestor with no `Employees` row, so it vanishes in the final join; levels are then counted from the dangling point. Downward walk: the orphan's subtree is never reached from the CEO, so those employees have no level and drop out of the inner join to `levels`. The approaches then *disagree*. Validate first: an anti-join for dangling `manager_id`s.
5. **"Can you do it without recursion?"** Not in one standard SQL query for unbounded depth. With a known maximum depth you can unroll self-joins, or iterate a bottom-up rollup in a procedure (section 6b). With a stored path column (e.g. `/1/3/6/`), the closure becomes a `LIKE 'prefix%'` join, the "materialised path" model.

## 9. Snowflake notes (UNVERIFIED)

`snowflake.sql` is approach 3 with the two `GROUP BY`s folded into one. What changes, and why:

- The closure is unpivoted into "as manager" and "as report" rows, then aggregated once with `COUNT_IF` / `IFF`. Snowflake may inline a CTE that is referenced twice and evaluate it twice. Folding guarantees one scan of the closure whichever choice the optimizer makes. The same folding was translated to MySQL syntax and passed every edge and differential test once (not kept as a solution); the Snowflake syntax itself is unverified.
- `ZEROIFNULL(x)` is `COALESCE(x, 0)`.
- `CONNECT BY` with `CONNECT_BY_ROOT` can build the closure: start a walk at every employee, follow `manager_id = PRIOR employee_id` downward, and `CONNECT_BY_ROOT employee_id` names the walk's start, which gives every (manager, report) pair. `LEVEL` gives the depth from the walk's start. The recursive CTE is more portable, and makes the carried salary explicit.
- No indexes. Each recursion level is a hash join, so the upward-versus-downward index lesson becomes a broadcast-versus-shuffle question (section 6c).

## 10. Pattern links

Same recursive-closure family:
- `42-produce-a-cte-that-can-return-the-upward-recommendation-chain-for-any-member`: the upward closure with a carried anchor column. This problem adds aggregation on top of it.
- `41-find-the-downward-recommendation-chain-for-member-id-1`: downward traversal from one root, and why it needs an index on the parent pointer.
- `39-tree-node`: the one-hop version (does a node have children?), no recursion.

Same "aggregate, then LEFT JOIN back with zeros" shape:
- `01-market-analysis-i`: count per key, then `COALESCE` for keys with no rows.
- `40-friend-requests-ii-who-has-the-most-friends`: one table read in two roles, aggregated per role, then combined.
