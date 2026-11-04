-- breaks: edge_typical, edge_date_order
-- MISTAKE: treating a cancelled row as disqualifying. The spec says cancelled rows are ignored, not that
-- their owner is excluded (user 4 and user 3 have converted and also have a cancelled row).
WITH per_user AS (
  SELECT user_id,
         AVG(CASE WHEN activity_type = 'free_trial' THEN activity_duration END) AS t,
         AVG(CASE WHEN activity_type = 'paid'       THEN activity_duration END) AS p
  FROM UserActivity
  WHERE user_id NOT IN (SELECT user_id FROM UserActivity WHERE activity_type = 'cancelled')
    AND activity_type IN ('free_trial', 'paid')
  GROUP BY user_id
)
SELECT user_id, ROUND(t, 2) AS trial_avg_duration, ROUND(p, 2) AS paid_avg_duration
FROM per_user WHERE t IS NOT NULL AND p IS NOT NULL
ORDER BY user_id;
