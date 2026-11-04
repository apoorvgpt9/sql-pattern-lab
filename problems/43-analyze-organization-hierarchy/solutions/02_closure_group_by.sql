-- Approach 2: same two recursive CTEs, but the per-manager numbers come from one GROUP BY over the
-- closure (joined to the reports' salaries), attached with a LEFT JOIN so non-managers keep a row.
WITH RECURSIVE
levels (employee_id, level) AS (
  SELECT employee_id, 1 FROM Employees WHERE manager_id IS NULL
  UNION ALL
  SELECT e.employee_id, l.level + 1
  FROM Employees e JOIN levels l ON e.manager_id = l.employee_id
),
reports (manager_id, report_id) AS (
  SELECT manager_id, employee_id FROM Employees WHERE manager_id IS NOT NULL
  UNION ALL
  SELECT r.manager_id, e.employee_id
  FROM reports r JOIN Employees e ON e.manager_id = r.report_id
),
team AS (                                          -- closure grain -> manager grain
  SELECT r.manager_id, COUNT(*) AS team_size, SUM(s.salary) AS team_salary
  FROM reports r JOIN Employees s ON s.employee_id = r.report_id
  GROUP BY r.manager_id
)
SELECT
  e.employee_id,
  e.employee_name,
  l.level,
  COALESCE(t.team_size, 0)              AS team_size,
  e.salary + COALESCE(t.team_salary, 0) AS budget
FROM Employees e
JOIN levels l     ON l.employee_id = e.employee_id
LEFT JOIN team t  ON t.manager_id  = e.employee_id
ORDER BY l.level ASC, budget DESC, e.employee_name ASC;
