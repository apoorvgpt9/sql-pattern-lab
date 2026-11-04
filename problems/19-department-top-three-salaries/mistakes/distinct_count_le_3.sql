-- breaks: edge_typical, edge_ties, edge_distinct_count_boundary
-- MISTAKE: the other off-by-one in the correlated version: "<= 3 higher distinct salaries" admits the
-- FOURTH distinct salary.
SELECT d.name AS Department, e.name AS Employee, e.salary AS Salary
FROM Employee e
JOIN Department d ON d.id = e.departmentId
WHERE (SELECT COUNT(DISTINCT e2.salary) FROM Employee e2
        WHERE e2.departmentId = e.departmentId AND e2.salary > e.salary) <= 3;
