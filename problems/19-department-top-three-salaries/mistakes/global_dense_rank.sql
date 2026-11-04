-- breaks: edge_typical, edge_ties, edge_distinct_count_boundary, edge_orphans
-- MISTAKE: forgets PARTITION BY: "top three distinct salaries" of the whole company, not of each
-- department. Only the three best-paid salary values overall survive.
WITH ranked AS (
  SELECT departmentId, name, salary, DENSE_RANK() OVER (ORDER BY salary DESC) AS rnk
  FROM Employee
)
SELECT d.name AS Department, r.name AS Employee, r.salary AS Salary
FROM ranked r JOIN Department d ON d.id = r.departmentId
WHERE r.rnk <= 3;
