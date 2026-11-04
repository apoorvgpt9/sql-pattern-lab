-- breaks: edge_date_order
-- MISTAKE: reading "converted FROM trial TO paid" as a date-order rule and requiring a paid row later than a
-- trial row. The spec only asks for users who have both kinds of rows; paid-before-trial and same-day users
-- are then dropped.
WITH per_user AS (
  SELECT user_id,
         AVG(CASE WHEN activity_type = 'free_trial' THEN activity_duration END) AS t,
         AVG(CASE WHEN activity_type = 'paid'       THEN activity_duration END) AS p,
         MIN(CASE WHEN activity_type = 'free_trial' THEN activity_date END)     AS first_trial,
         MAX(CASE WHEN activity_type = 'paid'       THEN activity_date END)     AS last_paid
  FROM UserActivity WHERE activity_type IN ('free_trial', 'paid') GROUP BY user_id
)
SELECT user_id, ROUND(t, 2) AS trial_avg_duration, ROUND(p, 2) AS paid_avg_duration
FROM per_user WHERE t IS NOT NULL AND p IS NOT NULL AND last_paid > first_trial
ORDER BY user_id;
