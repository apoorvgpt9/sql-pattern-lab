-- UNVERIFIED: Snowflake version of the optimal approach (03). CI cannot run Snowflake.
-- The Monday of each week is computed with DAYOFWEEKISO (Monday = 1), so the result does not
-- depend on the WEEK_START session parameter that DATE_TRUNC('week', ...) follows. See README section 9.
WITH weekly AS (
  SELECT employee_id,
         DATEADD(day, -(DAYOFWEEKISO(meeting_date) - 1), meeting_date) AS week_start,
         SUM(duration_hours) AS week_hours
  FROM meetings
  GROUP BY employee_id, week_start
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
