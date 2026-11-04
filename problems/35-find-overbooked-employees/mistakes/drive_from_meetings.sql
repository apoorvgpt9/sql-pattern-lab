-- breaks: edge_typical
-- MISTAKE: driving from meetings with a LEFT JOIN to employees. Meetings for an employee_id that
-- is not in employees produce a row with NULL name and department (employee 99).
WITH weekly AS (
  SELECT employee_id, YEARWEEK(meeting_date, 1) AS yw
  FROM meetings
  GROUP BY employee_id, YEARWEEK(meeting_date, 1)
  HAVING SUM(duration_hours) > 20
),
counted AS (
  SELECT employee_id, COUNT(*) AS meeting_heavy_weeks
  FROM weekly GROUP BY employee_id HAVING COUNT(*) >= 2
)
SELECT c.employee_id, e.employee_name, e.department, c.meeting_heavy_weeks
FROM counted c
LEFT JOIN employees e ON e.employee_id = c.employee_id
ORDER BY c.meeting_heavy_weeks DESC, e.employee_name;
