-- breaks: edge_multi_action_day, edge_no_streak
-- MISTAKE: building islands on the raw rows. Partitioning by (user, action) hides the second
-- action, so a multi-action day still counts as a 'view' day and the streak never breaks.
-- "Exactly one action per day" is a filter on (user, day) groups that must run first.
WITH clean AS (SELECT user_id, action_date, action FROM activity),
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
FROM ranked WHERE rn = 1
ORDER BY streak_length DESC, user_id;
