-- Approach 1 (brute force): for each employee, a correlated subquery builds that employee's weekly
-- totals and counts the heavy ones. Reads like the spec: "for each employee, how many weeks > 20h".
-- (MySQL 8.0.14+ allows the outer reference e.employee_id inside the derived table.)
WITH per_employee AS (
  SELECT e.employee_id, e.employee_name, e.department,
         (SELECT COUNT(*)
            FROM (SELECT SUM(m.duration_hours) AS week_hours
                    FROM meetings m
                   WHERE m.employee_id = e.employee_id
                   GROUP BY DATE_SUB(m.meeting_date, INTERVAL WEEKDAY(m.meeting_date) DAY)) w
           WHERE w.week_hours > 20) AS meeting_heavy_weeks
  FROM employees e
)
SELECT employee_id, employee_name, department, meeting_heavy_weeks
FROM per_employee
WHERE meeting_heavy_weeks >= 2
ORDER BY meeting_heavy_weeks DESC, employee_name;
