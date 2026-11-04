-- breaks: edge_ties, edge_distinct_count_boundary
-- MISTAKE: ROW_NUMBER() <= 3 returns the first three PEOPLE per department. The spec counts distinct
-- salary values, so tied employees (and everyone in a department with fewer than three salaries) must
-- not be cut off.
WITH ranked AS (
  SELECT departmentId, name, salary,
         ROW_NUMBER() OVER (PARTITION BY departmentId ORDER BY salary DESC, id) AS rn
  FROM Employee
)
SELECT d.name AS Department, r.name AS Employee, r.salary AS Salary
FROM ranked r JOIN Department d ON d.id = r.departmentId
WHERE r.rn <= 3;
