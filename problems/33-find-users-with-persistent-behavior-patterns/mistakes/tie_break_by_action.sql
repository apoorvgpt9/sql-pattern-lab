-- breaks: edge_tied_longest
-- MISTAKE (against this repo's stated assumption): breaking a tie between equally long streaks by
-- action name. It is deterministic, but it is not "the earliest streak": on edge_tied_longest it
-- reports 'code' (later) instead of 'test' (earlier). Any tie rule must be stated and tested.
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
),
ranked AS (
  SELECT user_id, action, streak_length, start_date, end_date,
         ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY streak_length DESC, action) AS rn
  FROM streaks
)
SELECT user_id, action, streak_length, start_date, end_date
FROM ranked WHERE rn = 1
ORDER BY streak_length DESC, user_id;
