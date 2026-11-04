-- breaks: edge_ties
-- MISTAKE: the brute-force "fewer than three higher" test counts higher-paid EMPLOYEES instead of higher
-- DISTINCT SALARIES. Two people at the top salary then make the third-highest salary look like the 4th.
SELECT d.name AS Department, e.name AS Employee, e.salary AS Salary
FROM Employee e
JOIN Department d ON d.id = e.departmentId
WHERE (SELECT COUNT(*) FROM Employee e2
        WHERE e2.departmentId = e.departmentId AND e2.salary > e.salary) < 3;
