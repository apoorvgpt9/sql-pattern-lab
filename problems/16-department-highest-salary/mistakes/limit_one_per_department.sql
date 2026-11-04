-- breaks: edge_ties, edge_zero_and_single
-- MISTAKE: picks one employee per department by sorting inside a correlated subquery
-- (the "LIMIT 1" instinct from top-1-per-group). It returns a single arbitrary winner on a tie.
SELECT d.name AS Department, e.name AS Employee, e.salary AS Salary
FROM Department d
JOIN Employee e
  ON e.id = (SELECT e2.id FROM Employee e2
              WHERE e2.departmentId = d.id
              ORDER BY e2.salary DESC, e2.id
              LIMIT 1);
