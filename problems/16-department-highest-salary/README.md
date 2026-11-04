# 16 · Department Highest Salary

## 1. Problem & trigger phrases

Original: [Department Highest Salary](https://leetcode.com/problems/department-highest-salary/) (LeetCode 184, medium). Read the statement there; this guide only restates the spec in its own words.

**Spec (own words):** for every department that has at least one employee, return the department name together with each employee whose salary equals the highest salary in that department. If several employees tie at the top, all of them are returned. Output columns are `Department`, `Employee`, `Salary`.

| Trigger phrase | What it forces in SQL |
|---|---|
| "highest salary in each of the departments" | Two words, two operations. *Highest* is a `MAX` (or a rank of 1). *In each* is a `GROUP BY departmentId` or `PARTITION BY departmentId`. A bare `MAX(salary)` over the whole table answers a different question. |
| (the example shows two tied employees) | The answer is **employees**, not departments, so after you know the maximum you must come back to the row level and keep every row that equals it. Use equality against the max (join back / correlated subquery) or `RANK()`/`DENSE_RANK()`. `ROW_NUMBER()` and `LIMIT 1` quietly drop ties. |

What is *not* in the wording: no "including departments with no employees". The department table only supplies a name, so an inner join is correct and a `LEFT JOIN` from `Department` is a mistake.

## 2. Schema & grain

| Table | One row means | Keys that matter here |
|---|---|---|
| `Employee` | one employee | `departmentId`, `salary`. `departmentId` is a logical foreign key that is not enforced: it can be NULL or point at a department that does not exist. |
| `Department` | one department | `id` (PK), `name` (used only to label the output) |

**Output grain:** one row per *top-paid employee per department*. That is not "one row per department": a department with a tie at the top contributes several rows, so the row count is at least the number of staffed departments and can be higher.

**Where the grain changes:** the query needs a department-grain fact (the maximum) and then returns to employee grain. There are two ways to do the round trip, and the choice is the whole problem:

- **Aggregate, then join back** (approaches 1 and 2): `GROUP BY departmentId` collapses employees to one row per department; the maximum is then compared against the employee rows, which restores employee grain and keeps ties naturally.
- **Rank in place** (approach 3): a window function adds the department-level fact as a column *without* changing grain. Nothing collapses, so nothing has to be joined back. The cost is that you must pick a ranking function that treats ties correctly.

## 3. Hint ladder

<details><summary>Hint 1</summary>

Pattern: **top-1 per group, keeping ties**. "Highest in each X" is a per-group maximum, and the answer is the *rows* that attain it, not just the maximum value.

</details>

<details><summary>Hint 2</summary>

Shape: (1) find, for each department, the number you are looking for (the maximum salary). (2) Get back to employees: keep the rows whose salary equals their own department's maximum. (3) Attach the department name. Two routes for step 1+2: aggregate and join back, or a window function that puts the department's rank on each employee row.

</details>

<details><summary>Hint 3</summary>

Key trick: ties. If you rank, use `RANK()` (or `DENSE_RANK()`) and keep rank 1: tied employees share rank 1. If you join back, join on **department and salary**, never salary alone. Salary alone matches employees from other departments whose pay happens to equal this department's maximum.

</details>

## 4. Decomposition

Split the wording into a *fact to compute* ("highest salary… in each department") and a *set of rows to return* ("the employee(s) who earn it").

1. **`ranked`: for each employee, compute their rank by salary inside their department.**
   *Why a window function here:* we need a department-level comparison for every employee row, and we must keep employee grain. `GROUP BY` would collapse the rows we have to return. `PARTITION BY departmentId` is the "in each department", and `ORDER BY salary DESC` is the "highest".
2. **Filter `rnk = 1`.**
   *Why a filter here, and why `RANK`:* "the employees who earn the highest" means keep every row whose rank is first. Tied employees share rank 1, so they all pass. A window function cannot be filtered in the same `SELECT` it is computed in, which is why step 1 is its own CTE.
3. **Join `Department` for the name.**
   *Why a JOIN here (inner):* the name is a label for a row that already exists. A department with no employees has no row to label, and the spec says it must not appear.

```sql
WITH ranked AS (                                  -- step 1: department-level fact, employee grain kept
  SELECT departmentId, name, salary,
         RANK() OVER (PARTITION BY departmentId ORDER BY salary DESC) AS rnk
  FROM Employee
)
SELECT d.name   AS Department,                    -- step 3: label
       r.name   AS Employee,
       r.salary AS Salary
FROM ranked r
JOIN Department d ON d.id = r.departmentId
WHERE r.rnk = 1;                                  -- step 2: keep every tied top earner
```

Self-check before you submit: (a) pick a department you know has a tie at the top and confirm all tied employees are present; (b) confirm the output has no department whose name does not exist in `Department`.

## 5. Approaches: brute force → optimal

### Approach 1: correlated subquery per employee (`solutions/01_correlated_subquery.sql`)

```sql
SELECT d.name AS Department, e.name AS Employee, e.salary AS Salary
FROM Employee e
JOIN Department d ON d.id = e.departmentId
WHERE e.salary = (SELECT MAX(e2.salary) FROM Employee e2
                   WHERE e2.departmentId = e.departmentId);
```

**Why it is correct:** the subquery computes the maximum of the employee's own department; the equality keeps everyone who attains it, so ties survive. The inner join to `Department` drops employees with a NULL or unknown department. For a NULL `departmentId`, `e2.departmentId = NULL` is never true, the subquery returns NULL, and the comparison fails: the employee is excluded, consistent with the join.

**Cost model (reasoned):** conceptually one subquery per employee row. With no index on `departmentId`, each execution scans the whole `Employee` table, which is employees × employees. MySQL 8.0 may transform the subquery, so check `EXPLAIN` for a *dependent subquery* rather than assuming it. With `indexes.sql` (`departmentId, salary`), each `MAX` becomes a single index-boundary read for that department, and the cost becomes roughly one index probe per employee.

### Approach 2: join to a per-department maximum (`solutions/02_join_to_group_max.sql`)

```sql
SELECT d.name AS Department, e.name AS Employee, e.salary AS Salary
FROM Employee e
JOIN (SELECT departmentId, MAX(salary) AS max_salary
        FROM Employee GROUP BY departmentId) m
  ON m.departmentId = e.departmentId AND m.max_salary = e.salary
JOIN Department d ON d.id = e.departmentId;
```

**Why it is correct:** the derived table has one row per department with the maximum; joining back on `(departmentId, salary)` restores the employees who hold it, ties included. Both join keys are required: with `salary` alone, an employee in department A matches the maximum of department B.

**Cost model (reasoned):** two scans of `Employee` (one to aggregate, one to join back) plus a hash join between the full table and the small aggregate. The aggregate has one row per department, so it is cheap to build and probe; the dominant cost is the second scan and the join over every employee row.

### Approach 3 (optimal): rank in a window (`solutions/03_rank_window.sql`)

The SQL is the assembled query in section 4.

**Why it is correct:** `RANK()` assigns 1 to every employee whose salary is the department's highest, so ties pass `rnk = 1`. `DENSE_RANK()` would work identically for rank 1; they differ only for ranks 2 and above (see problem 19).

**Cost model (reasoned):** one scan of `Employee`. The window has to see each department's rows sorted by salary, which means a sort (or an index read in that order) over the whole table, then a filter. There is no join back and no second pass over `Employee`. The sort is the price: it is O(n log n) in the worst case where approach 2's aggregate is a single linear pass. Which of these wins on one machine depends on whether `(departmentId, salary)` is indexed, so read the "with indexes" and "without" tables below rather than assuming.

**Measured** (`gen.py` data, generated by the bench workflow; the table is filled in automatically, so never type numbers here):

<!-- BENCH:16-department-highest-salary -->
<!-- /BENCH -->

### Why the optimal one wins

Approach 3 gets the department-level fact without leaving employee grain, so it reads each row once and has no join back to get wrong: the `salary`-only join in approach 2 is the classic bug, and it cannot be written here. It is also the form that maps best to distributed engines (section 6c), where a window is one shuffle by `departmentId`. The honest caveat is single-machine MySQL: with the `(departmentId, salary)` index the aggregate-and-join-back form (approach 2) can overtake the window, because the per-department `MAX` becomes an index read while the window still processes every row. So "optimal" here means "least ways to be wrong and the best-behaved without a special index", confirmed or contradicted by the bench tables.

## 6. At scale

**(a) What breaks first.** *Reasoned, then checked by the bench table:* approach 1 without an index goes first, because every employee triggers a scan of the table (quadratic growth). Approach 2 follows when the second scan plus the join over all employee rows stops fitting in memory. Approach 3's sort over all rows is the last to degrade, but it is a full sort, so it has a hard memory-or-spill threshold of its own.

**(b) One machine, ~1M–100M rows.**
- `indexes.sql` adds `Employee (departmentId, salary)`. It is *covering* for the aggregate and the window (no other `Employee` column is needed to find the maximum). For approach 3 the window's partition/order matches the index, so the sort can disappear; for approach 1 each `MAX` is one index read.
- The query still needs `name` to output, so the final row fetch is one lookup per returned row. That is small, since only the top earners are returned.
- If the output is read often and `Employee` changes rarely, store the result in a summary table (section 6d) and read that.

**(c) Distributed engines, billions of rows. *Reasoned, not measured.***
- *Shuffle:* a window with `PARTITION BY departmentId` needs all rows of a department on one worker, so it shuffles every employee row once. Approach 2 can pre-aggregate `MAX` locally on each worker and shuffle only one row per (worker, department), but it must then bring the maxima back to the employee rows (a second shuffle, or a broadcast of the small aggregate, which is usually possible because there are few departments). So at this shape the aggregate-then-broadcast-join can move less data than the window; the window is simpler and avoids reading the table twice. Treat both as candidates and look at the query plan's bytes shuffled.
- *Skew:* one very large department would put all its rows on one worker in the window plan. Pre-aggregating the maximum (`MAX` is decomposable) removes that for the aggregation step; the join back then needs a broadcast, not a shuffle on `departmentId`.
- *Snowflake:* there is no index to add. Micro-partition pruning does not help here, since the whole table is read; cost is dominated by the scan and the shuffle. `QUALIFY` expresses approach 3 without a CTE.
- *Things to avoid:* a global `ORDER BY` over the whole result (the spec says any order), and `COUNT(DISTINCT)`-style tricks to find ties. Approximate functions are not appropriate here: the answer is an exact set of people.

**(d) The data-engineering answer.** Per-department maxima rarely need recomputing from scratch. Maintain `dept_top(departmentId, max_salary)` incrementally. Insert-only batches can use `GREATEST`:

```sql
-- Snowflake / ANSI MERGE (UNVERIFIED): fold a new batch into the maxima.
MERGE INTO dept_top t
USING (SELECT departmentId, MAX(salary) AS batch_max
       FROM employee_batch                    -- only rows not yet applied (by id watermark)
       WHERE departmentId IS NOT NULL
       GROUP BY departmentId) s
ON t.departmentId = s.departmentId
WHEN MATCHED THEN UPDATE SET max_salary = GREATEST(t.max_salary, s.batch_max)
WHEN NOT MATCHED THEN INSERT (departmentId, max_salary) VALUES (s.departmentId, s.batch_max);

-- MySQL equivalent (no MERGE):
INSERT INTO dept_top (departmentId, max_salary)
SELECT departmentId, MAX(salary) FROM employee_batch
WHERE departmentId IS NOT NULL GROUP BY departmentId
ON DUPLICATE KEY UPDATE max_salary = GREATEST(max_salary, VALUES(max_salary));
```

Caveat interviewers probe: `MAX` is **not retractable**. If the top earner leaves or takes a pay cut, the new maximum cannot be derived from the old one. The robust pattern is to recompute only the *touched* departments (delete their rows from the stored top-earner table and re-insert them from `Employee` with the section 4 query restricted to those departments), driven by a change feed that lists affected `departmentId`s. Re-running a batch is then idempotent for free.

## 7. Edge cases

Each "breaks" claim below is checked by execution: `mistakes/*.sql` are the tempting wrong queries, and the harness asserts that each one fails every dataset it names (`harness/test_mistakes.py`).

| Case | Dataset | Wrong queries it catches (`mistakes/`) |
|---|---|---|
| Typical mix; a salary equal to another department's maximum | `tests/edge_typical.sql` | `global_max` (only the company-wide top earner), `join_max_on_salary_only` (returns employees of the wrong department) |
| Two employees tied at the maximum; a tie one step *below* the maximum; everyone equal | `tests/edge_ties.sql` | `row_number_top1`, `limit_one_per_department` (one arbitrary winner), `global_max` |
| Employee with NULL `departmentId`; employee pointing at a missing department; department with no employees. The orphans are paid more than anyone else | `tests/edge_orphans.sql` | `global_max` (picks the orphan, then loses it at the join), `left_join_department` (emits departments that have no top earner) |
| Single-employee department; maximum equal to 0 shared by two people | `tests/edge_zero_and_single.sql` | `row_number_top1`, `limit_one_per_department` (tie at 0), `global_max` |
| `Employee` empty, `Department` not | `tests/edge_no_employees.sql` | `left_join_department` (returns every department with NULLs) |

No approach in `solutions/` is broken by any of these. NULL `salary` is outside the spec (`rules.nulls: n/a`, and the schema declares it `NOT NULL`); if it were allowed, `MAX` would ignore NULLs, and a department where *every* salary is NULL would silently disappear under the equality-based approaches.

## 8. Interviewer follow-ups

1. **"Return the top two earners per department."** Same window, `WHERE rnk <= 2`. The follow-up is really "does rank 2 mean the second-highest *salary* or the second-highest *person*?": that is `DENSE_RANK` versus `RANK`, and problem 19 is this question.
2. **"Return exactly one employee per department, pick the earliest hire on a tie."** Now ties are *not* wanted, so `ROW_NUMBER() OVER (PARTITION BY departmentId ORDER BY salary DESC, hire_date, id)` is the right tool. The tie-break must end in a unique column or the result is non-deterministic.
3. **"Include departments with no employees."** `LEFT JOIN` from `Department` and accept NULL employee/salary. If the top-earner condition goes in the `WHERE`, the left join collapses to an inner join. Put it in the CTE, or in the `ON` clause (problem 01 is that trap).
4. **"What if salary can be NULL?"** `MAX` ignores NULL; `RANK() ... ORDER BY salary DESC` puts NULLs *last* in MySQL and *first* in some other engines, so state `NULLS LAST` explicitly where supported, or filter them out first.
5. **"Why not `SELECT departmentId, name, MAX(salary) ... GROUP BY departmentId`?"** Under `ONLY_FULL_GROUP_BY` it is rejected. With the check disabled, `name` is taken from an arbitrary row of the group, which is not necessarily the one with the maximum salary. The aggregate and the row it came from are not linked.

## 9. Snowflake notes (UNVERIFIED)

`snowflake.sql` is approach 3 with `QUALIFY`. What changes, and why:

- `QUALIFY RANK() OVER (...) = 1` filters on a window function directly, removing the CTE. It is shorter and states intent, and the plan is expected to be the same as the CTE form.
- There are no secondary indexes, so `indexes.sql` has no equivalent. The only physical-design lever is clustering, which does not help a query that reads the whole table.
- Unquoted identifiers are upper-cased (`DEPARTMENTID`). The sample quotes the output aliases (`"Department"`) to preserve the case the spec asks for; downstream code that is case-sensitive will care.
- `MAX_BY(name, salary)` returns one name per group, so it is tempting here. It cannot return ties, so it fails the spec for the same reason `ROW_NUMBER()` does.

## 10. Pattern links

Same pattern (rank or max per group, keep tied rows):
- `19-department-top-three-salaries`: the same shape with `DENSE_RANK() <= 3`; the rank function now matters beyond rank 1.
- `17-seasonal-sales-analysis`: top-1 per group *after* aggregating to (season, category), with a multi-key tie-break that removes ties instead of keeping them.
- `18-find-stores-with-inventory-imbalance`: top-1 and bottom-1 per group in the same query, via two rankings.
- `20-product-sales-analysis-iii`: "earliest year per product, keep every row in it": join back to a per-key minimum, the mirror image of approach 2.
- `26-find-consistently-improving-employees`: top-N per group feeding a further condition.
