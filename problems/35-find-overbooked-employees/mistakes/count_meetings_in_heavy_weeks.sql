-- breaks: edge_typical
-- MISTAKE: one GROUP BY too few. Joining the heavy-week list back to meetings and counting rows
-- counts meetings in heavy weeks, not weeks (Ann: 5 meetings in her 2 heavy weeks).
WITH weekly AS (
  SELECT employee_id, YEARWEEK(meeting_date, 1) AS yw
  FROM meetings
  GROUP BY employee_id, YEARWEEK(meeting_date, 1)
  HAVING SUM(duration_hours) > 20
)
SELECT e.employee_id, e.employee_name, e.department, COUNT(*) AS meeting_heavy_weeks
FROM weekly w
JOIN meetings m ON m.employee_id = w.employee_id AND YEARWEEK(m.meeting_date, 1) = w.yw
JOIN employees e ON e.employee_id = w.employee_id
GROUP BY e.employee_id, e.employee_name, e.department
HAVING COUNT(DISTINCT w.yw) >= 2
ORDER BY meeting_heavy_weeks DESC, e.employee_name;
