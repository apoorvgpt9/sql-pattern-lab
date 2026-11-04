-- breaks: edge_no_conversion
-- MISTAKE: "converted = has more than one kind of activity". Trial + cancelled, or paid + cancelled, are two kinds
-- but not a conversion; those users come back with a NULL average on one side.
SELECT user_id,
       ROUND(AVG(CASE WHEN activity_type = 'free_trial' THEN activity_duration END), 2) AS trial_avg_duration,
       ROUND(AVG(CASE WHEN activity_type = 'paid'       THEN activity_duration END), 2) AS paid_avg_duration
FROM UserActivity
GROUP BY user_id
HAVING COUNT(DISTINCT activity_type) >= 2
ORDER BY user_id;
