-- Approach 1 (brute force): for each employee, ask "is my salary the maximum of my department?"
-- Natural first attempt: it restates the requirement one employee at a time.
-- Equality (not "no one earns more") keeps every employee tied at the maximum.
SELECT
  d.name   AS Department,
  e.name   AS Employee,
  e.salary AS Salary
FROM Employee e
JOIN Department d
  ON d.id = e.departmentId
WHERE e.salary = (SELECT MAX(e2.salary)
                    FROM Employee e2
                   WHERE e2.departmentId = e.departmentId);
