-- Approach 1 (brute force): for every user, ask "average trial duration?" and "average paid duration?",
-- then keep the users for whom both questions have an answer.
-- AVG over zero rows is NULL, so a missing type shows up as NULL and the filter removes the user.
-- Cancelled rows are never selected by either subquery, so they cannot leak into an average.
SELECT
  x.user_id,
  ROUND(x.t, 2) AS trial_avg_duration,
  ROUND(x.p, 2) AS paid_avg_duration
FROM (
  SELECT
    u.user_id,
    (SELECT AVG(a.activity_duration) FROM UserActivity a
      WHERE a.user_id = u.user_id AND a.activity_type = 'free_trial') AS t,
    (SELECT AVG(a.activity_duration) FROM UserActivity a
      WHERE a.user_id = u.user_id AND a.activity_type = 'paid')       AS p
  FROM (SELECT DISTINCT user_id FROM UserActivity) u
) x
WHERE x.t IS NOT NULL AND x.p IS NOT NULL
ORDER BY x.user_id;
