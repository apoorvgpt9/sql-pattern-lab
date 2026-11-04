-- breaks: edge_typical, edge_deep_chain, edge_order
-- MISTAKE: "direct and indirect reports" read as direct reports only: one self-join, no recursion.
-- Correct for flat orgs (edge_star passes), wrong as soon as anyone has a grand-report.
WITH RECURSIVE levels (employee_id, level) AS (
  SELECT employee_id, 1 FROM Employees WHERE manager_id IS NULL
  UNION ALL
  SELECT e.employee_id, l.level + 1 FROM Employees e JOIN levels l ON e.manager_id = l.employee_id
)
SELECT e.employee_id, e.employee_name, l.level,
       COUNT(d.employee_id)                 AS team_size,
       e.salary + COALESCE(SUM(d.salary), 0) AS budget
FROM Employees e
JOIN levels l ON l.employee_id = e.employee_id
LEFT JOIN Employees d ON d.manager_id = e.employee_id
GROUP BY e.employee_id, e.employee_name, l.level, e.salary
ORDER BY l.level ASC, budget DESC, e.employee_name ASC;
