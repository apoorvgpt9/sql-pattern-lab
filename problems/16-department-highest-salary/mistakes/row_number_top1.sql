-- breaks: edge_ties, edge_zero_and_single
-- MISTAKE: ROW_NUMBER() = 1 returns exactly one employee per department. The spec says every
-- employee tied at the maximum must be returned, so the other tied employees are dropped.
WITH ranked AS (
  SELECT departmentId, name, salary,
         ROW_NUMBER() OVER (PARTITION BY departmentId ORDER BY salary DESC) AS rn
  FROM Employee
)
SELECT d.name AS Department, r.name AS Employee, r.salary AS Salary
FROM ranked r JOIN Department d ON d.id = r.departmentId
WHERE r.rn = 1;
