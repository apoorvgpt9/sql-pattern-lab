-- breaks: edge_boundary_20_hours, edge_none_qualify
-- MISTAKE (against this repo's stated assumption): >= 20 instead of > 20. A week of exactly
-- 20.00 hours is not "more than 20". The reference solution this spec was drawn from uses >= 20;
-- README "Assumptions" explains why the requirement's wording wins here.
WITH weekly AS (
  SELECT employee_id, DATE_SUB(meeting_date, INTERVAL WEEKDAY(meeting_date) DAY) AS wk, SUM(duration_hours) AS week_hours
  FROM meetings
  GROUP BY employee_id, DATE_SUB(meeting_date, INTERVAL WEEKDAY(meeting_date) DAY)
  HAVING SUM(duration_hours) >= 20
),
counted AS (
  SELECT employee_id, COUNT(*) AS meeting_heavy_weeks
  FROM weekly GROUP BY employee_id HAVING COUNT(*) >= 2
)
SELECT e.employee_id, e.employee_name, e.department, c.meeting_heavy_weeks
FROM counted c
JOIN employees e ON e.employee_id = c.employee_id
ORDER BY c.meeting_heavy_weeks DESC, e.employee_name;
