-- UNVERIFIED: Snowflake version of the optimal approach. CI cannot run Snowflake.
-- MAX_BY collapses approach 3 (window + join) into ONE GROUP BY: each latest-row column is taken
-- from the row with the largest (event_date, event_id) key. See README section 9.
WITH per_user AS (
  SELECT user_id,
         MAX_BY(event_type,     TO_CHAR(event_date, 'YYYY-MM-DD') || '|' || LPAD(event_id, 12, '0')) AS last_type,
         MAX_BY(plan_name,      TO_CHAR(event_date, 'YYYY-MM-DD') || '|' || LPAD(event_id, 12, '0')) AS current_plan,
         MAX_BY(monthly_amount, TO_CHAR(event_date, 'YYYY-MM-DD') || '|' || LPAD(event_id, 12, '0')) AS current_monthly_amount,
         MAX(monthly_amount)                               AS max_historical_amount,
         DATEDIFF(day, MIN(event_date), MAX(event_date))   AS days_as_subscriber,
         COUNT_IF(event_type = 'downgrade')                AS n_downgrades
  FROM subscription_events
  GROUP BY user_id
)
SELECT user_id, current_plan, current_monthly_amount, max_historical_amount, days_as_subscriber
FROM per_user
WHERE last_type <> 'cancel'
  AND n_downgrades >= 1
  AND current_monthly_amount < 0.5 * max_historical_amount
  AND days_as_subscriber >= 60
ORDER BY days_as_subscriber DESC, user_id;
