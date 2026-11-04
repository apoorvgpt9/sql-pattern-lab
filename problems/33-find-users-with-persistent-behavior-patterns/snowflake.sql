-- UNVERIFIED: Snowflake version of the optimal approach (03). CI cannot run Snowflake.
-- QUALIFY replaces the clean-day GROUP BY and the ranking CTE. Differences are in README section 9.
WITH clean AS (
  SELECT user_id, action_date, action
  FROM activity
  QUALIFY COUNT(*) OVER (PARTITION BY user_id, action_date) = 1
),
streaks AS (
  SELECT user_id, action, COUNT(*) AS streak_length,
         MIN(action_date) AS start_date, MAX(action_date) AS end_date
  FROM (
    SELECT user_id, action, action_date,
           DATEADD(day, -ROW_NUMBER() OVER (PARTITION BY user_id, action ORDER BY action_date),
                   action_date) AS island
    FROM clean
  )
  GROUP BY user_id, action, island
  HAVING COUNT(*) >= 5
)
SELECT user_id, action, streak_length, start_date, end_date
FROM streaks
QUALIFY ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY streak_length DESC, start_date) = 1
ORDER BY streak_length DESC, user_id;
