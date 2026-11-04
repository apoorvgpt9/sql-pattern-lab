-- breaks: edge_sunday_ends_week
-- MISTAKE: WEEK(d) with the default mode 0 starts weeks on SUNDAY. A Sunday meeting then lands
-- in the following week instead of with the Monday before it. The spec says Monday to Sunday:
-- use WEEKDAY() (Monday = 0), YEARWEEK(d, 1) or WEEK(d, 1) with its year.
WITH weekly AS (
  SELECT employee_id, YEARWEEK(meeting_date) AS wk, SUM(duration_hours) AS week_hours
  FROM meetings
  GROUP BY employee_id, YEARWEEK(meeting_date)
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
