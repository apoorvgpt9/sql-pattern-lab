-- Approach 2: flag-and-count islands. A day starts a new streak unless yesterday was a clean day
-- with the same action (LAG). A running SUM of the start flags numbers the streaks.
-- Clean days are found with a window count per (user, day) instead of a NOT EXISTS.
WITH counted AS (
  SELECT user_id, action_date, action,
         COUNT(*) OVER (PARTITION BY user_id, action_date) AS actions_that_day
  FROM activity
),
clean AS (
  SELECT user_id, action_date, action FROM counted WHERE actions_that_day = 1
),
flagged AS (
  SELECT user_id, action, action_date,
         CASE WHEN LAG(action_date) OVER w = action_date - INTERVAL 1 DAY THEN 0 ELSE 1 END AS is_start
  FROM clean
  WINDOW w AS (PARTITION BY user_id, action ORDER BY action_date)
),
numbered AS (
  SELECT user_id, action, action_date,
         SUM(is_start) OVER (PARTITION BY user_id, action ORDER BY action_date
                             ROWS UNBOUNDED PRECEDING) AS streak_no
  FROM flagged
),
streaks AS (
  SELECT user_id, action, COUNT(*) AS streak_length,
         MIN(action_date) AS start_date, MAX(action_date) AS end_date
  FROM numbered
  GROUP BY user_id, action, streak_no
  HAVING COUNT(*) >= 5
),
ranked AS (
  SELECT user_id, action, streak_length, start_date, end_date,
         ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY streak_length DESC, start_date) AS rn
  FROM streaks
)
SELECT user_id, action, streak_length, start_date, end_date
FROM ranked
WHERE rn = 1
ORDER BY streak_length DESC, user_id;
