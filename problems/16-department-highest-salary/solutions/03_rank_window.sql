-- Approach 3 (optimal): one pass over Employee with RANK() per department; keep rank 1.
-- RANK (or DENSE_RANK) gives tied employees the same rank, so all of them survive the filter.
-- ROW_NUMBER would number the tied employees 1, 2, ... and silently drop all but one.
WITH ranked AS (
  SELECT
    departmentId,
    name,
    salary,
    RANK() OVER (PARTITION BY departmentId ORDER BY salary DESC) AS rnk
  FROM Employee
)
SELECT
  d.name    AS Department,
  r.name    AS Employee,
  r.salary  AS Salary
FROM ranked r
JOIN Department d
  ON d.id = r.departmentId
WHERE r.rnk = 1;
