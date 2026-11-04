-- breaks: edge_calendar_boundaries
-- MISTAKE: action_date - ROW_NUMBER() without INTERVAL. In a numeric context MySQL reads the date
-- as the number 20231231, so 20231231 - 2 and 20240101 - 3 differ: the label jumps at every
-- month and year boundary and the streak is split. Use DATE_SUB(d, INTERVAL rn DAY) or DATEDIFF.
WITH clean AS (
  SELECT user_id, action_date, MIN(action) AS action
  FROM activity GROUP BY user_id, action_date HAVING COUNT(*) = 1
),
labelled AS (
  SELECT user_id, action, action_date,
         action_date - ROW_NUMBER() OVER (PARTITION BY user_id, action ORDER BY action_date) AS island
  FROM clean
),
streaks AS (
  SELECT user_id, action, COUNT(*) AS streak_length,
         MIN(action_date) AS start_date, MAX(action_date) AS end_date
  FROM labelled
  GROUP BY user_id, action, island
  HAVING COUNT(*) >= 5
),
ranked AS (
  SELECT user_id, action, streak_length, start_date, end_date,
         ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY streak_length DESC, start_date) AS rn
  FROM streaks
)
SELECT user_id, action, streak_length, start_date, end_date
FROM ranked WHERE rn = 1
ORDER BY streak_length DESC, user_id;
