-- breaks: edge_typical, edge_ties, edge_orphans, edge_zero_and_single
-- MISTAKE: forgets that "highest" is per department and compares against the company-wide maximum.
-- Only the global top earner(s) survive, so every other department is missing.
SELECT d.name AS Department, e.name AS Employee, e.salary AS Salary
FROM Employee e
JOIN Department d ON d.id = e.departmentId
WHERE e.salary = (SELECT MAX(salary) FROM Employee);
