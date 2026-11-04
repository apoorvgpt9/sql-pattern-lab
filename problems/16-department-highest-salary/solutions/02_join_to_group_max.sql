-- Approach 2: compute the maximum per department once, then join back to the employees on
-- BOTH department and salary. Joining on salary alone would match other departments' maxima.
SELECT
  d.name   AS Department,
  e.name   AS Employee,
  e.salary AS Salary
FROM Employee e
JOIN (SELECT departmentId, MAX(salary) AS max_salary
        FROM Employee
       GROUP BY departmentId) m
  ON  m.departmentId = e.departmentId
  AND m.max_salary   = e.salary
JOIN Department d
  ON d.id = e.departmentId;
