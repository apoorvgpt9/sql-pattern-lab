-- Approach 2: one grouped query per type (each is one row per user), INNER JOINed on user_id.
-- The inner join is the "has both" test: a user missing from either CTE has no partner and disappears.
-- Two scans of the table, no per-user loop.
WITH trial AS (
  SELECT user_id, AVG(activity_duration) AS avg_dur
  FROM UserActivity
  WHERE activity_type = 'free_trial'
  GROUP BY user_id
),
paid AS (
  SELECT user_id, AVG(activity_duration) AS avg_dur
  FROM UserActivity
  WHERE activity_type = 'paid'
  GROUP BY user_id
)
SELECT
  t.user_id,
  ROUND(t.avg_dur, 2) AS trial_avg_duration,
  ROUND(p.avg_dur, 2) AS paid_avg_duration
FROM trial t
JOIN paid p ON p.user_id = t.user_id
ORDER BY t.user_id;
