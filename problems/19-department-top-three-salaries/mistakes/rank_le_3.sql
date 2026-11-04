-- breaks: edge_ties
-- MISTAKE: RANK() <= 3. After a tie RANK skips numbers (90, 90, 80, 70 get ranks 1, 1, 3, 4), so the
-- 70s are the 4th rank and are dropped although 70 is only the third DISTINCT salary.
WITH ranked AS (
  SELECT departmentId, name, salary,
         RANK() OVER (PARTITION BY departmentId ORDER BY salary DESC) AS rnk
  FROM Employee
)
SELECT d.name AS Department, r.name AS Employee, r.salary AS Salary
FROM ranked r JOIN Department d ON d.id = r.departmentId
WHERE r.rnk <= 3;
