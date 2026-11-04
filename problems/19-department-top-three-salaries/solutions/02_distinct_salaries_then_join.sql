-- Approach 2: first reduce to the distinct (department, salary) pairs, pick the top three pairs per
-- department by counting how many pairs are higher, then join back to the employees on both keys.
-- The counting now runs over distinct salaries, not over employees.
WITH sal AS (
  SELECT DISTINCT departmentId, salary
  FROM Employee
), top3 AS (
  SELECT a.departmentId, a.salary
  FROM sal a
  WHERE (SELECT COUNT(*)
           FROM sal b
          WHERE b.departmentId = a.departmentId
            AND b.salary > a.salary) < 3
)
SELECT
  d.name   AS Department,
  e.name   AS Employee,
  e.salary AS Salary
FROM top3 t
JOIN Employee e
  ON  e.departmentId = t.departmentId
  AND e.salary       = t.salary
JOIN Department d
  ON d.id = t.departmentId;
