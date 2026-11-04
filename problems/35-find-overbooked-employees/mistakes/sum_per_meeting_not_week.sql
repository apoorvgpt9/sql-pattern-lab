-- breaks: edge_typical, edge_sunday_ends_week, edge_week_spans_new_year
-- MISTAKE: skipping the weekly SUM and testing each meeting against 20 hours. "More than 50% of a
-- 40-hour week" is a property of the week's total, so several shorter meetings must add up first.
WITH heavy AS (
  SELECT employee_id, COUNT(DISTINCT YEARWEEK(meeting_date, 1)) AS meeting_heavy_weeks
  FROM meetings
  WHERE duration_hours > 20
  GROUP BY employee_id
  HAVING COUNT(DISTINCT YEARWEEK(meeting_date, 1)) >= 2
)
SELECT e.employee_id, e.employee_name, e.department, h.meeting_heavy_weeks
FROM heavy h JOIN employees e ON e.employee_id = h.employee_id
ORDER BY h.meeting_heavy_weeks DESC, e.employee_name;
