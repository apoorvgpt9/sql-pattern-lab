-- Approach 1 (brute force): find each user's latest event with a correlated ORDER BY ... LIMIT 1,
-- then check every other rule with its own correlated subquery against the user's full history.
-- Natural first attempt: one subquery per sentence of the spec.
WITH latest AS (
  SELECT e.user_id, e.event_date, e.event_type, e.plan_name, e.monthly_amount
  FROM subscription_events e
  WHERE e.event_id = (SELECT x.event_id
                        FROM subscription_events x
                       WHERE x.user_id = e.user_id
                       ORDER BY x.event_date DESC, x.event_id DESC
                       LIMIT 1)
),
checked AS (
  SELECT l.user_id, l.event_type, l.plan_name, l.monthly_amount,
         (SELECT MAX(h.monthly_amount) FROM subscription_events h
           WHERE h.user_id = l.user_id) AS max_amount,
         DATEDIFF(l.event_date, (SELECT MIN(f.event_date) FROM subscription_events f
                                  WHERE f.user_id = l.user_id)) AS days_span,
         EXISTS (SELECT 1 FROM subscription_events d
                  WHERE d.user_id = l.user_id AND d.event_type = 'downgrade') AS has_downgrade
  FROM latest l
)
SELECT user_id,
       plan_name      AS current_plan,
       monthly_amount AS current_monthly_amount,
       max_amount     AS max_historical_amount,
       days_span      AS days_as_subscriber
FROM checked
WHERE event_type <> 'cancel'
  AND has_downgrade
  AND monthly_amount < 0.5 * max_amount
  AND days_span >= 60
ORDER BY days_as_subscriber DESC, user_id;
