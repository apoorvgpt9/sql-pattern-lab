# 19 · Department Top Three Salaries

## 1. Problem & trigger phrases

Original: [Department Top Three Salaries](https://leetcode.com/problems/department-top-three-salaries/) (LeetCode 185, hard). Read the statement there; this guide only restates the spec in its own words.

**Spec (own words):** in every department, a "high earner" is anyone whose salary is one of the department's three highest **distinct salary values**. Return department name, employee name and salary for all of them. A department with fewer than three distinct salaries returns all its employees; a department with ties can return more than three rows.

| Trigger phrase | What it forces in SQL |
|---|---|
| "top three unique salaries" | The unit that is counted is the **salary value**, not the person. Rank with `DENSE_RANK()` (tied people share a rank; ranks never skip) and keep `<= 3`. `ROW_NUMBER()` counts people, and `RANK()` skips after a tie, so both cut off people who belong. |
| "in each of the departments" | `PARTITION BY departmentId`. Forgetting it ranks the whole company, and only three salary values overall survive. |

Not in the wording: nothing about departments with no employees, or employees with no department. Both are absent from the output because the name has to come from `Department`, so the join to `Department` is an inner join.

## 2. Schema & grain

| Table | One row means | Keys that matter here |
|---|---|---|
| `Employee` | one employee | `departmentId`, `salary` (name for the output). `departmentId` is a logical foreign key, not enforced: it can be NULL or point at a department that does not exist. |
| `Department` | one department | `id` (PK), `name` (label only) |

**Output grain:** one row per qualifying *employee* (not per department, not per salary value). The row count per department is not fixed: a department can contribute 1 to many rows.

**Where the grain changes:** nowhere, if you use a window function: `DENSE_RANK()` adds a column and every employee row survives until the filter. That is the point of the window approach, and also the source of the subtlety: the *unit being ranked* (distinct salary values) is coarser than the *unit being returned* (employees). The brute-force approaches show this explicitly, because they have to reduce to distinct (department, salary) pairs and then come back to employees.

## 3. Hint ladder

<details><summary>Hint 1</summary>

Pattern: **top-N per group over distinct values, keeping ties**. Same family as "highest salary per department", but the cut-off is "the third distinct value", not "the first row".

</details>

<details><summary>Hint 2</summary>

Shape: (1) within each department, rank salaries so that equal salaries share a rank and no rank number is skipped. (2) Keep ranks 1 to 3. (3) Attach the department name. No `GROUP BY` is needed, since you must keep every employee.

</details>

<details><summary>Hint 3</summary>

Key trick: the ranking function. `DENSE_RANK() OVER (PARTITION BY departmentId ORDER BY salary DESC) <= 3`. If you cannot use a window function: an employee qualifies if fewer than three **distinct** salaries in their department are strictly higher than theirs (`COUNT(DISTINCT …) < 3`, not `COUNT(*)`).

</details>

## 4. Decomposition

"Top three unique salaries in each department": *each department* is the partition, *unique salaries* is the thing being ranked, *top three* is the cut-off.

1. **`ranked`: give each employee the dense rank of their salary within their department.**
   *Why a window function here:* the rank is a per-department fact that must sit next to each employee row, and we cannot lose employees by collapsing. *Why `DENSE_RANK`:* it is the only ranking function whose numbers mean "which distinct value is this". Two people at the top share rank 1, and the next salary is rank 2, not 3.
2. **Filter `rnk <= 3`.**
   *Why a filter here:* the question is a cut-off on that rank. It is separate from step 1 because a window function cannot be filtered in the `SELECT` that computes it.
3. **Join `Department`.**
   *Why an inner JOIN here:* the department name labels rows that already exist. Employees with no matching department cannot be labelled, so they are not part of the answer.

```sql
WITH ranked AS (                                         -- step 1: rank of the salary VALUE, per department
  SELECT departmentId, name, salary,
         DENSE_RANK() OVER (PARTITION BY departmentId ORDER BY salary DESC) AS rnk
  FROM Employee
)
SELECT d.name   AS Department,                           -- step 3: label
       r.name   AS Employee,
       r.salary AS Salary
FROM ranked r
JOIN Department d ON d.id = r.departmentId
WHERE r.rnk <= 3;                                        -- step 2: three distinct values, ties included
```

Self-check before you submit: pick a department with a tie at its third salary and confirm both tied people appear. Then pick one with only two distinct salaries and confirm all its employees appear.

## 5. Approaches: brute force → optimal

### Approach 1: count the higher distinct salaries per employee (`solutions/01_correlated_distinct_count.sql`)

```sql
SELECT d.name AS Department, e.name AS Employee, e.salary AS Salary
FROM Employee e
JOIN Department d ON d.id = e.departmentId
WHERE (SELECT COUNT(DISTINCT e2.salary) FROM Employee e2
        WHERE e2.departmentId = e.departmentId AND e2.salary > e.salary) < 3;
```

**Why it is correct:** "e is one of the top three distinct salaries" is equivalent to "fewer than three distinct salaries in e's department are strictly higher". For the top salary the count is 0; for the third distinct value it is 2; for the fourth it is 3, which is excluded. Employees tied at a value all see the same count, so they all pass or all fail together. `COUNT(*)` instead of `COUNT(DISTINCT …)` is the classic bug.

**Cost model (reasoned):** one subquery per employee row, each reading the higher-paid employees of that department and de-duplicating their salaries. With no supporting index every execution scans the whole table, which is quadratic. With `indexes.sql` (`departmentId, salary`) the probe becomes a range read of only the higher-salary entries of one department. Work per employee is proportional to the number of employees above them in their department, which makes large departments the expensive ones.

### Approach 2: reduce to distinct salaries first, then join back (`solutions/02_distinct_salaries_then_join.sql`)

```sql
WITH sal  AS (SELECT DISTINCT departmentId, salary FROM Employee),
     top3 AS (SELECT a.departmentId, a.salary FROM sal a
               WHERE (SELECT COUNT(*) FROM sal b
                       WHERE b.departmentId = a.departmentId AND b.salary > a.salary) < 3)
SELECT d.name, e.name, e.salary
FROM top3 t JOIN Employee e ON e.departmentId = t.departmentId AND e.salary = t.salary
            JOIN Department d ON d.id = t.departmentId;
```

**Why it is correct:** the first CTE changes the grain to (department, salary value), which is exactly the unit "top three distinct" is defined on, so a plain `COUNT(*)` of higher rows is now the number of higher *distinct* salaries. Joining back on both keys returns every employee holding a selected value, ties included.

**Cost model (reasoned):** the quadratic part (the correlated count) now runs over distinct (department, salary) pairs, not over employees, so it shrinks by the average number of employees per salary value. The price is a second scan of `Employee` to join back, plus the `DISTINCT` (a group-by under the hood).

### Approach 3 (optimal): `DENSE_RANK` (`solutions/03_dense_rank_window.sql`)

The SQL is the assembled query in section 4.

**Why it is correct:** `DENSE_RANK` over a descending salary gives the value of the rank "1, 2, 3, …" for successive distinct salaries, identical for ties. The filter `<= 3` is therefore exactly "one of the three highest distinct salaries".

**Cost model (reasoned):** one scan of `Employee`, one sort per partition (department, salary descending), and a streaming rank computation; no subquery per row and no second scan. With the `(departmentId, salary)` index the sort can be replaced by an index scan in the right order. The cost is O(n log n) in the worst case, not O(n²).

**Measured** (`gen.py` data, generated by the bench workflow; the table is filled in automatically, so never type numbers here):

<!-- BENCH:19-department-top-three-salaries -->
_Measured 2026-11-04 by the bench workflow: MySQL 8.0.46, AMD EPYC 7763 64-Core Processor, 2 vCPU. Median of 3 runs after 1 warm-up; each statement capped at 60 s. Sizes are main-table rows from `gen.py`. Raw numbers and EXPLAIN ANALYZE: `bench/results/19-department-top-three-salaries.json`._

**Without indexes**

| Solution | 1,000 rows | 100,000 rows | 1,000,000 rows | × slower than optimal @ 1,000,000 |
|---|---:|---:|---:|---:|
| `01_correlated_distinct_count` | 169 ms | timeout >60s | timeout >60s † | > 20× |
| `02_distinct_salaries_then_join` | 5.62 ms | 581 ms | 18.6 s | 6.1× |
| `03_dense_rank_window` (optimal) | 2.83 ms | 251 ms | 3.07 s | 1.0× |

† not run at this size: it already timed out at a smaller size.

**With `indexes.sql`**

| Solution | 1,000 rows | 100,000 rows | 1,000,000 rows | × slower than optimal @ 1,000,000 |
|---|---:|---:|---:|---:|
| `01_correlated_distinct_count` | 11.2 ms | 1.36 s | 15.9 s | 5.1× |
| `02_distinct_salaries_then_join` | 3.75 ms | 353 ms | 9.26 s | 3.0× |
| `03_dense_rank_window` (optimal) | 2.87 ms | 253 ms | 3.1 s | 1.0× |

> GitHub-hosted runners are shared, noisy VMs: compare the ratios between rows, not the absolute times.
<!-- /BENCH -->

### Why the optimal one wins

Approach 3 does a single pass and states the requirement in the function name: the dense rank *is* the distinct-salary position. Approaches 1 and 2 re-derive that rank through a per-row (or per-value) count, which is both more work and more places to be wrong (`COUNT(*)` vs `COUNT(DISTINCT)`, `<` vs `<=`). The caveat is the same as in problem 16: with a covering `(departmentId, salary)` index MySQL can make the correlated form cheap on one machine, so read the "with indexes" and "without" tables rather than assuming. In distributed engines the window is one shuffle by department and a local sort, while a per-row correlated subquery is not an option at all (it is rewritten to a join with a non-equi condition, which is expensive).

## 6. At scale

**(a) What breaks first.** *Reasoned, then checked by the bench table:* approach 1 without an index (employees × employees, with a `DISTINCT` inside each probe). Approach 2 is less bad because its quadratic part is over distinct salaries. Approach 3 degrades last, at the memory limit of the sort for the largest department.

**(b) One machine, ~1M–100M rows.**
- `indexes.sql` adds `Employee (departmentId, salary)`. It is covering for the ranking, the correlated count and the distinct list, because no other column is needed to decide who qualifies. For approach 3 the window's partition and order match the index, so the sort can disappear; for approach 1 each probe becomes a range read.
- If one department is huge, the per-partition sort is the memory risk. Because only the top three distinct values matter, an alternative is to find the third-highest distinct salary per department first (with `DENSE_RANK` over the distinct list, which is small) and then filter employees with `salary >= threshold`. That does the expensive sort over distinct values rather than over employees (reasoned).

**(c) Distributed engines, billions of rows. *Reasoned, not measured.***
- *Shuffle:* a window with `PARTITION BY departmentId` needs all rows of a department together, so one shuffle on `departmentId` moves every employee row. A cheaper plan for this specific question: aggregate to distinct (department, salary) pairs locally first (map-side `DISTINCT`), shuffle those, rank them, and broadcast-join the small top-three list back to the employees. This moves distinct pairs instead of all rows (the saving is large when salaries repeat a lot, small if they are all unique).
- *Skew:* one department with most of the employees makes one worker do most of the sort. The distinct-first plan removes that, because the number of distinct salaries in a department is bounded by the salary range, not by headcount.
- *Snowflake:* `QUALIFY DENSE_RANK() OVER (...) <= 3` is the shortest form. No secondary indexes. Micro-partition pruning does not help: all rows are read.
- *Things to avoid:* a global `ORDER BY` (any order is allowed), and `COUNT(DISTINCT …)` correlated per row. `APPROX_*` functions are not appropriate: the answer is a specific set of people.

**(d) The data-engineering answer.** Top-three-per-department changes only when someone in that department is hired, leaves or is repriced. Keep `dept_top3(departmentId, salary)` (the three highest distinct values) and refresh only the departments touched by a change feed:

```sql
-- Snowflake / ANSI MERGE (UNVERIFIED): recompute the top-three salary VALUES of changed departments only.
MERGE INTO dept_top3 t
USING (SELECT departmentId, salary
       FROM (SELECT departmentId, salary,
                    DENSE_RANK() OVER (PARTITION BY departmentId ORDER BY salary DESC) AS rnk
             FROM (SELECT DISTINCT departmentId, salary FROM Employee
                    WHERE departmentId IN (SELECT departmentId FROM employee_changes)) x) y
       WHERE rnk <= 3) s
ON t.departmentId = s.departmentId AND t.salary = s.salary
WHEN NOT MATCHED THEN INSERT (departmentId, salary) VALUES (s.departmentId, s.salary);

-- ...and remove values that fell out of the top three (a MERGE ... WHEN NOT MATCHED BY SOURCE is not
-- available in Snowflake, so a separate DELETE restricted to the changed departments is used):
DELETE FROM dept_top3 t
WHERE departmentId IN (SELECT departmentId FROM employee_changes)
  AND NOT EXISTS (SELECT 1 FROM (/* the same ranked query as above */) s
                   WHERE s.departmentId = t.departmentId AND s.salary = t.salary);

-- MySQL: DELETE the changed departments' rows from dept_top3 and INSERT ... SELECT the section 4 query
-- restricted to them, inside one transaction.
```

The report then joins `Employee` to this small table on `(departmentId, salary)`. Caveats interviewers probe: top-N is **not retractable**, since when the current third-highest value disappears the new one comes from the detail rows, so a refresh must re-read the department rather than patch the old answer; the refresh must be idempotent (recomputing from the source for the touched keys is); and deletes must be handled by the same recompute.

## 7. Edge cases

Each "breaks" claim below is checked by execution: `mistakes/*.sql` are the tempting wrong queries, and the harness asserts that each one fails every dataset it names (`harness/test_mistakes.py`).

| Case | Dataset | Wrong queries it catches (`mistakes/`) |
|---|---|---|
| Five distinct salaries: ranks 4 and 5 cut | `tests/edge_typical.sql` | `dense_rank_lt_3`, `distinct_count_le_3` (the two off-by-ones), `global_dense_rank` |
| Two people at the top and two at the third distinct salary (5 rows from one department) | `tests/edge_ties.sql` | `row_number_le_3`, `rank_le_3` (rank 4 after a tie), `count_rows_not_distinct` |
| Fewer than three distinct salaries; a one-person department; all employees on one salary; exactly 3 distinct; 4 distinct | `tests/edge_distinct_count_boundary.sql` | `row_number_le_3`, `dense_rank_lt_3`, `distinct_count_le_3`, `global_dense_rank` |
| NULL `departmentId`; missing department; department with no employees; the orphans are the best paid | `tests/edge_orphans.sql` | `global_dense_rank`, `left_join_department` (rows with a NULL department name) |
| `Employee` empty | `tests/edge_no_employees.sql` | none; all approaches return no rows |

No approach in `solutions/` is broken by any of these. NULL `salary` is outside the spec (`rules.nulls: n/a`, and the schema declares it `NOT NULL`).

## 8. Interviewer follow-ups

1. **"Top N, with N as a parameter."** Replace `3` with the parameter. In the correlated form, `< N`; in the window form, `rnk <= N`. Note that the result size is not bounded by N because of ties.
2. **"Now exactly three people per department, ties broken by hire date."** The unit changes from salary values to people: use `ROW_NUMBER() OVER (PARTITION BY departmentId ORDER BY salary DESC, hire_date, id) <= 3`. A unique last tie-break key is mandatory or the result is non-deterministic.
3. **"What is the difference between `RANK`, `DENSE_RANK` and `ROW_NUMBER` on salaries 90, 90, 80, 70?"** `ROW_NUMBER` = 1, 2, 3, 4; `RANK` = 1, 1, 3, 4; `DENSE_RANK` = 1, 1, 2, 3. For "top three distinct" only `DENSE_RANK` leaves 70 inside the cut-off.
4. **"Do it without window functions."** Approach 1 (or 2). State the cost (quadratic without an index) and the `COUNT(DISTINCT)` pitfall.
5. **"Make it fast for a table of billions of employees."** Do not rank employees. Find the third-highest distinct salary per department from the distinct list (section 6b/6c), then filter employees by `salary >= that threshold`; or maintain the per-department top-three values incrementally (section 6d).

## 9. Snowflake notes (UNVERIFIED)

`snowflake.sql` is approach 3 with `QUALIFY`. What changes, and why:

- `QUALIFY DENSE_RANK() OVER (...) <= 3` filters directly on the window function, removing the CTE. Shorter, same plan expected.
- No secondary indexes, so `indexes.sql` has no equivalent. The cost is the scan plus the shuffle on `departmentId`.
- Correlated subqueries with `COUNT(DISTINCT …)` (approach 1) are supported in Snowflake, but the optimiser decorrelates them into a join with an inequality condition, which is much more expensive than the window; do not port approach 1.
- Unquoted identifiers are upper-cased; the sample quotes the output aliases to keep the case the spec shows.

## 10. Pattern links

Same pattern (rank per group, keep ties, cut-off):
- `16-department-highest-salary`: the N = 1 case, where `RANK` and `DENSE_RANK` coincide; this problem is where they stop being interchangeable.
- `17-seasonal-sales-analysis`: top-1 per group after aggregating, with ties *removed* by a third sort key.
- `18-find-stores-with-inventory-imbalance`: two rankings per group, folded to one row.
- `26-find-consistently-improving-employees`: top-N per group feeding a further condition.
- `45-median-order-amount-per-store`: ranking within a group to find a middle element, using `ROW_NUMBER` and a count.
