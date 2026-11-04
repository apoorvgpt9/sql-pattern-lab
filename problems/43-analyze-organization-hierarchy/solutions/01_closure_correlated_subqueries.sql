-- Approach 1 (brute force): two recursive CTEs (levels from the CEO down; every (manager, report)
-- pair, walking down), then one correlated subquery per employee for each number.
-- Natural first attempt: it reads like the spec, one employee and one metric at a time.
WITH RECURSIVE
levels (employee_id, level) AS (
  SELECT employee_id, 1 FROM Employees WHERE manager_id IS NULL
  UNION ALL
  SELECT e.employee_id, l.level + 1
  FROM Employees e JOIN levels l ON e.manager_id = l.employee_id
),
reports (manager_id, report_id) AS (              -- closure: every direct or indirect report
  SELECT manager_id, employee_id FROM Employees WHERE manager_id IS NOT NULL
  UNION ALL
  SELECT r.manager_id, e.employee_id
  FROM reports r JOIN Employees e ON e.manager_id = r.report_id
)
SELECT
  e.employee_id,
  e.employee_name,
  l.level,
  (SELECT COUNT(*) FROM reports r WHERE r.manager_id = e.employee_id) AS team_size,
  e.salary + (SELECT COALESCE(SUM(s.salary), 0)
                FROM reports r JOIN Employees s ON s.employee_id = r.report_id
               WHERE r.manager_id = e.employee_id) AS budget
FROM Employees e
JOIN levels l ON l.employee_id = e.employee_id
ORDER BY l.level ASC, budget DESC, e.employee_name ASC;
