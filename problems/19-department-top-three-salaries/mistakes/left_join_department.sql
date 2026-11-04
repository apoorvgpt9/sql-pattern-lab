-- breaks: edge_orphans
-- MISTAKE: LEFT JOIN to Department after ranking. Employees whose department is NULL or missing form
-- their own partitions, rank 1, and come out with a NULL department name.
WITH ranked AS (
  SELECT departmentId, name, salary,
         DENSE_RANK() OVER (PARTITION BY departmentId ORDER BY salary DESC) AS rnk
  FROM Employee
)
SELECT d.name AS Department, r.name AS Employee, r.salary AS Salary
FROM ranked r LEFT JOIN Department d ON d.id = r.departmentId
WHERE r.rnk <= 3;
