-- breaks: edge_week_spans_new_year
-- MISTAKE: grouping by (YEAR(d), WEEK(d, 1)). The week Monday 2024-12-30 .. Sunday 2025-01-05 gets
-- (2024, 53) for its Monday and (2025, 1) for the rest, so one week becomes two half-weeks.
-- YEARWEEK(d, 1) assigns the whole week to one year; a week-start DATE avoids the question.
WITH weekly AS (
  SELECT employee_id, CONCAT(YEAR(meeting_date), '-', WEEK(meeting_date, 1)) AS wk, SUM(duration_hours) AS week_hours
  FROM meetings
  GROUP BY employee_id, CONCAT(YEAR(meeting_date), '-', WEEK(meeting_date, 1))
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
