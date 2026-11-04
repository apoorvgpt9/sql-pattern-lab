-- breaks: edge_typical, edge_lone_ceo, edge_deep_chain, edge_order, edge_star
-- MISTAKE: COUNT(*) after a LEFT JOIN to the closure counts the all-NULL row a non-manager gets,
-- so every individual contributor has team_size 1 instead of 0.
WITH RECURSIVE
levels (employee_id, level) AS (
  SELECT employee_id, 1 FROM Employees WHERE manager_id IS NULL
  UNION ALL
  SELECT e.employee_id, l.level + 1 FROM Employees e JOIN levels l ON e.manager_id = l.employee_id
),
reports (manager_id, report_id) AS (
  SELECT manager_id, employee_id FROM Employees WHERE manager_id IS NOT NULL
  UNION ALL
  SELECT r.manager_id, e.employee_id FROM reports r JOIN Employees e ON e.manager_id = r.report_id
)
SELECT e.employee_id, e.employee_name, l.level,
       COUNT(*)                              AS team_size,
       e.salary + COALESCE(SUM(s.salary), 0) AS budget
FROM Employees e
JOIN levels l ON l.employee_id = e.employee_id
LEFT JOIN reports r   ON r.manager_id = e.employee_id
LEFT JOIN Employees s ON s.employee_id = r.report_id
GROUP BY e.employee_id, e.employee_name, l.level, e.salary
ORDER BY l.level ASC, budget DESC, e.employee_name ASC;
