-- Approach 3 (optimal): one pass. Drop the cancelled rows, group by user, and pivot the two types into two
-- AVG(CASE ...) columns. A type the user never has gives AVG over no rows = NULL, so "both are not NULL" is
-- exactly "converted". No join, no per-user loop.
WITH per_user AS (
  SELECT
    user_id,
    AVG(CASE WHEN activity_type = 'free_trial' THEN activity_duration END) AS t,
    AVG(CASE WHEN activity_type = 'paid'       THEN activity_duration END) AS p
  FROM UserActivity
  WHERE activity_type IN ('free_trial', 'paid')
  GROUP BY user_id
)
SELECT
  user_id,
  ROUND(t, 2) AS trial_avg_duration,
  ROUND(p, 2) AS paid_avg_duration
FROM per_user
WHERE t IS NOT NULL AND p IS NOT NULL
ORDER BY user_id;
