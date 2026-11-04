-- breaks: edge_typical
-- MISTAKE: joins the per-department maxima back to Employee on salary alone, forgetting the
-- department. An employee whose salary equals ANOTHER department's maximum is returned even though
-- they are not the top earner of their own department.
SELECT d.name AS Department, e.name AS Employee, e.salary AS Salary
FROM Employee e
JOIN (SELECT departmentId, MAX(salary) AS max_salary FROM Employee GROUP BY departmentId) m
  ON m.max_salary = e.salary
JOIN Department d ON d.id = e.departmentId;
