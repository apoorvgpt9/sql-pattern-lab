-- breaks: edge_typical, edge_ties, edge_distinct_count_boundary
-- MISTAKE: off by one in the cut-off (< 3 instead of <= 3): only the top TWO distinct salaries come out.
WITH ranked AS (
  SELECT departmentId, name, salary,
         DENSE_RANK() OVER (PARTITION BY departmentId ORDER BY salary DESC) AS rnk
  FROM Employee
)
SELECT d.name AS Department, r.name AS Employee, r.salary AS Salary
FROM ranked r JOIN Department d ON d.id = r.departmentId
WHERE r.rnk < 3;
