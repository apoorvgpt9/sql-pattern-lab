-- Approach 3 (optimal): date minus ROW_NUMBER() days labels each streak.
--   clean   : GROUP BY (user, day) HAVING COUNT(*) = 1; MIN(action) is that day's only action.
--   label   : within (user, action) ordered by date, action_date - rn DAYS is constant on a run
--             of consecutive days and jumps at every gap (including a removed multi-action day).
--   streaks : GROUP BY the label; keep >= 5 days.
--   longest : ROW_NUMBER per user by length DESC, then earliest start (README "Assumptions").
WITH clean AS (
  SELECT user_id, action_date, MIN(action) AS action
  FROM activity
  GROUP BY user_id, action_date
  HAVING COUNT(*) = 1
),
labelled AS (
  SELECT user_id, action, action_date,
         DATE_SUB(action_date, INTERVAL
                  ROW_NUMBER() OVER (PARTITION BY user_id, action ORDER BY action_date) DAY) AS island
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
FROM ranked
WHERE rn = 1
ORDER BY streak_length DESC, user_id;
