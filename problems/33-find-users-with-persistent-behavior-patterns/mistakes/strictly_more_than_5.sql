-- breaks: edge_typical, edge_multi_action_day, edge_action_change, edge_calendar_boundaries, edge_tied_longest
-- MISTAKE: "at least 5" written as > 5 (or HAVING DATEDIFF(MAX, MIN) >= 5, which needs 6 days).
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
  HAVING DATEDIFF(MAX(action_date), MIN(action_date)) >= 5
),
ranked AS (
  SELECT user_id, action, streak_length, start_date, end_date,
         ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY streak_length DESC, start_date) AS rn
  FROM streaks
)
SELECT user_id, action, streak_length, start_date, end_date
FROM ranked WHERE rn = 1
ORDER BY streak_length DESC, user_id;
