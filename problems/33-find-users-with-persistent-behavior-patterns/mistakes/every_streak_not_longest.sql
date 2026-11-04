-- breaks: edge_longest_per_user, edge_tied_longest
-- MISTAKE: stopping after the HAVING. The output grain is one row per user, so a user with two
-- qualifying streaks must be reduced to the longest one.
WITH clean AS (
  SELECT user_id, action_date, MIN(action) AS action
  FROM activity GROUP BY user_id, action_date HAVING COUNT(*) = 1
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
)
SELECT user_id, action, streak_length, start_date, end_date
FROM streaks
ORDER BY streak_length DESC, user_id;
