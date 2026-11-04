-- Approach 3 (optimal): DENSE_RANK per department; keep ranks 1..3. DENSE_RANK gives tied salaries the
-- same rank and does not skip numbers afterwards, so the rank IS "which distinct salary value this is".
-- RANK would skip (1, 1, 3, 4) and ROW_NUMBER would number tied employees separately.
WITH ranked AS (
  SELECT
    departmentId,
    name,
    salary,
    DENSE_RANK() OVER (PARTITION BY departmentId ORDER BY salary DESC) AS rnk
  FROM Employee
)
SELECT
  d.name    AS Department,
  r.name    AS Employee,
  r.salary  AS Salary
FROM ranked r
JOIN Department d
  ON d.id = r.departmentId
WHERE r.rnk <= 3;
