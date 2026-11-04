-- Approach 1 (brute force): an employee is in the top three if FEWER THAN THREE distinct salaries in
-- their department are higher than theirs. Reads exactly like the definition of "top three distinct".
SELECT
  d.name   AS Department,
  e.name   AS Employee,
  e.salary AS Salary
FROM Employee e
JOIN Department d
  ON d.id = e.departmentId
WHERE (SELECT COUNT(DISTINCT e2.salary)
         FROM Employee e2
        WHERE e2.departmentId = e.departmentId
          AND e2.salary > e.salary) < 3;
