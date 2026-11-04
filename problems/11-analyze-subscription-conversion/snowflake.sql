-- UNVERIFIED: Snowflake version of the optimal approach (03). CI cannot run Snowflake.
-- Same shape as MySQL; differences are noted in README section 9.
SELECT
  user_id,
  ROUND(AVG(IFF(activity_type = 'free_trial', activity_duration, NULL)), 2) AS trial_avg_duration,
  ROUND(AVG(IFF(activity_type = 'paid',       activity_duration, NULL)), 2) AS paid_avg_duration
FROM UserActivity
WHERE activity_type IN ('free_trial', 'paid')
GROUP BY user_id
HAVING COUNT_IF(activity_type = 'free_trial') > 0
   AND COUNT_IF(activity_type = 'paid')       > 0
ORDER BY user_id;
