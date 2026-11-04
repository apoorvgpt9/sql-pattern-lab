-- Approach 3 (optimal): ONE recursion, walking UP from every employee and carrying their salary.
-- Each row (employee_id, salary, ancestor) says "this employee sits under this ancestor".
-- Grouped by ancestor it gives team_size and the reports' salary total; grouped by employee it
-- gives the number of ancestors, i.e. level - 1. Every step is a primary-key lookup (going up).
WITH RECURSIVE chain (employee_id, salary, ancestor) AS (
  SELECT employee_id, salary, manager_id
  FROM Employees
  WHERE manager_id IS NOT NULL
  UNION ALL
  SELECT c.employee_id, c.salary, m.manager_id
  FROM chain c
  JOIN Employees m ON m.employee_id = c.ancestor
  WHERE m.manager_id IS NOT NULL
),
as_manager AS (                                    -- per ancestor: everyone under them
  SELECT ancestor AS employee_id, COUNT(*) AS team_size, SUM(salary) AS team_salary
  FROM chain
  GROUP BY ancestor
),
as_report AS (                                     -- per employee: how many people are above them
  SELECT employee_id, COUNT(*) AS n_above
  FROM chain
  GROUP BY employee_id
)
SELECT
  e.employee_id,
  e.employee_name,
  1 + COALESCE(r.n_above, 0)             AS level,
  COALESCE(m.team_size, 0)               AS team_size,
  e.salary + COALESCE(m.team_salary, 0)  AS budget
FROM Employees e
LEFT JOIN as_manager m ON m.employee_id = e.employee_id
LEFT JOIN as_report  r ON r.employee_id = e.employee_id
ORDER BY level ASC, budget DESC, e.employee_name ASC;
