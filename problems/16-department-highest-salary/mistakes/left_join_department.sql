-- breaks: edge_no_employees, edge_orphans
-- MISTAKE: LEFT JOINs from Department to Employee "to keep every department". The spec says a
-- department without employees must not appear; this returns it with NULL employee and salary.
SELECT d.name AS Department, e.name AS Employee, e.salary AS Salary
FROM Department d
LEFT JOIN Employee e
  ON e.departmentId = d.id
 AND e.salary = (SELECT MAX(e2.salary) FROM Employee e2 WHERE e2.departmentId = d.id);
