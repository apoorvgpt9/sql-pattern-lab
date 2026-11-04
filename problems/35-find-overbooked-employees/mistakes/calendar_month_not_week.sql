-- breaks: edge_typical, edge_ordering
-- MISTAKE: bucketing by calendar month instead of week. Two heavy weeks in one month collapse
-- into one bucket, and all of a month's hours are compared with a 20-hour weekly limit.
WITH weekly AS (
  SELECT employee_id, DATE_FORMAT(meeting_date, '%Y-%m') AS wk, SUM(duration_hours) AS week_hours
  FROM meetings
  GROUP BY employee_id, DATE_FORMAT(meeting_date, '%Y-%m')
  HAVING SUM(duration_hours) > 20
),
counted AS (
  SELECT employee_id, COUNT(*) AS meeting_heavy_weeks
  FROM weekly GROUP BY employee_id HAVING COUNT(*) >= 2
)
SELECT e.employee_id, e.employee_name, e.department, c.meeting_heavy_weeks
FROM counted c
JOIN employees e ON e.employee_id = c.employee_id
ORDER BY c.meeting_heavy_weeks DESC, e.employee_name;
