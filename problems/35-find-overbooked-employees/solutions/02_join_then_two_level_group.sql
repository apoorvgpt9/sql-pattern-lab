-- Approach 2: join first, then aggregate twice. Level 1 groups the joined rows by
-- (employee, week) and keeps heavy weeks; level 2 counts them per employee.
-- YEARWEEK(d, 1) is a Monday-start week key that never splits a week across a year boundary.
WITH heavy_weeks AS (
  SELECT e.employee_id, e.employee_name, e.department, YEARWEEK(m.meeting_date, 1) AS yw
  FROM employees e
  JOIN meetings m ON m.employee_id = e.employee_id
  GROUP BY e.employee_id, e.employee_name, e.department, YEARWEEK(m.meeting_date, 1)
  HAVING SUM(m.duration_hours) > 20
)
SELECT employee_id, employee_name, department, COUNT(*) AS meeting_heavy_weeks
FROM heavy_weeks
GROUP BY employee_id, employee_name, department
HAVING COUNT(*) >= 2
ORDER BY meeting_heavy_weeks DESC, employee_name;
