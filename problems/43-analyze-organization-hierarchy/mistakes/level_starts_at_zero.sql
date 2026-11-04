-- breaks: edge_typical, edge_lone_ceo, edge_deep_chain, edge_order, edge_star
-- MISTAKE: anchoring the CEO at depth 0 (the usual "distance from root") when the spec says the
-- CEO is level 1. Every level is off by one; the order is unchanged, so it looks right at a glance.
WITH RECURSIVE chain (employee_id, salary, ancestor) AS (
  SELECT employee_id, salary, manager_id FROM Employees WHERE manager_id IS NOT NULL
  UNION ALL
  SELECT c.employee_id, c.salary, m.manager_id
  FROM chain c JOIN Employees m ON m.employee_id = c.ancestor
  WHERE m.manager_id IS NOT NULL
),
as_manager AS (SELECT ancestor AS employee_id, COUNT(*) AS team_size, SUM(salary) AS team_salary
               FROM chain GROUP BY ancestor),
as_report  AS (SELECT employee_id, COUNT(*) AS n_above FROM chain GROUP BY employee_id)
SELECT e.employee_id, e.employee_name,
       COALESCE(r.n_above, 0)                AS level,
       COALESCE(m.team_size, 0)              AS team_size,
       e.salary + COALESCE(m.team_salary, 0) AS budget
FROM Employees e
LEFT JOIN as_manager m ON m.employee_id = e.employee_id
LEFT JOIN as_report  r ON r.employee_id = e.employee_id
ORDER BY level ASC, budget DESC, e.employee_name ASC;
