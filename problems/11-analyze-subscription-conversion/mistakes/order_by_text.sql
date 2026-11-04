-- breaks: edge_ordering
-- MISTAKE: sorting the id as text (for example after concatenating or casting it for display): '100' < '20' < '30' < '7'.
WITH per_user AS (
  SELECT user_id,
         AVG(CASE WHEN activity_type = 'free_trial' THEN activity_duration END) AS t,
         AVG(CASE WHEN activity_type = 'paid'       THEN activity_duration END) AS p
  FROM UserActivity WHERE activity_type IN ('free_trial', 'paid') GROUP BY user_id
)
SELECT user_id, ROUND(t, 2) AS trial_avg_duration, ROUND(p, 2) AS paid_avg_duration
FROM per_user WHERE t IS NOT NULL AND p IS NOT NULL
ORDER BY CAST(user_id AS CHAR);
