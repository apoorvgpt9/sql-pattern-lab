-- Approach 3 (optimal): aggregate meetings all the way down to employee grain on the narrow
-- table, then join the (few) qualifying employees for their name and department.
--   weekly : (employee, week start) -> hours; keep weeks > 20
--   counted: employee -> number of heavy weeks; keep >= 2
WITH weekly AS (
  SELECT employee_id,
         DATE_SUB(meeting_date, INTERVAL WEEKDAY(meeting_date) DAY) AS week_start,
         SUM(duration_hours) AS week_hours
  FROM meetings
  GROUP BY employee_id, DATE_SUB(meeting_date, INTERVAL WEEKDAY(meeting_date) DAY)
  HAVING SUM(duration_hours) > 20
),
counted AS (
  SELECT employee_id, COUNT(*) AS meeting_heavy_weeks
  FROM weekly
  GROUP BY employee_id
  HAVING COUNT(*) >= 2
)
SELECT e.employee_id, e.employee_name, e.department, c.meeting_heavy_weeks
FROM counted c
JOIN employees e ON e.employee_id = c.employee_id
ORDER BY c.meeting_heavy_weeks DESC, e.employee_name;
