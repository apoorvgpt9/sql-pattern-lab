-- breaks: edge_typical, edge_rounding
-- MISTAKE: TRUNCATE(x, 2) instead of ROUND(x, 2). 7.6667 becomes 7.66, and the exact 0.125 becomes 0.12.
WITH per_user AS (
  SELECT user_id,
         AVG(CASE WHEN activity_type = 'free_trial' THEN activity_duration END) AS t,
         AVG(CASE WHEN activity_type = 'paid'       THEN activity_duration END) AS p
  FROM UserActivity WHERE activity_type IN ('free_trial', 'paid') GROUP BY user_id
)
SELECT user_id, TRUNCATE(t, 2) AS trial_avg_duration, TRUNCATE(p, 2) AS paid_avg_duration
FROM per_user WHERE t IS NOT NULL AND p IS NOT NULL
ORDER BY user_id;
