-- breaks: edge_typical, edge_no_conversion
-- MISTAKE: LEFT JOIN from the trial side. "Converted" needs a paid partner; a LEFT JOIN keeps trial-only users
-- with a NULL paid average. (edge_no_conversion has trial-only users too).
WITH trial AS (SELECT user_id, AVG(activity_duration) AS avg_dur FROM UserActivity WHERE activity_type = 'free_trial' GROUP BY user_id),
     paid  AS (SELECT user_id, AVG(activity_duration) AS avg_dur FROM UserActivity WHERE activity_type = 'paid'       GROUP BY user_id)
SELECT t.user_id, ROUND(t.avg_dur, 2) AS trial_avg_duration, ROUND(p.avg_dur, 2) AS paid_avg_duration
FROM trial t LEFT JOIN paid p ON p.user_id = t.user_id
ORDER BY t.user_id;
