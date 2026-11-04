-- Approach 3 (optimal): two passes, each doing the cheapest thing for its job.
-- Pass 1 ranks events per user to find the latest one (ROW_NUMBER with the event_id tiebreak):
--   the only fact that needs an order. Pass 2 aggregates the full history per user with a plain
--   GROUP BY: one value per user, computed once. Join the two (1:1 on user_id).
WITH ranked AS (
  SELECT user_id, event_type, plan_name, monthly_amount,
         ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY event_date DESC, event_id DESC) AS rn
  FROM subscription_events
),
history AS (
  SELECT user_id,
         MAX(monthly_amount)                       AS max_amount,
         DATEDIFF(MAX(event_date), MIN(event_date)) AS days_span,
         SUM(event_type = 'downgrade')             AS n_downgrades
  FROM subscription_events
  GROUP BY user_id
)
SELECT r.user_id,
       r.plan_name      AS current_plan,
       r.monthly_amount AS current_monthly_amount,
       h.max_amount     AS max_historical_amount,
       h.days_span      AS days_as_subscriber
FROM ranked r
JOIN history h ON h.user_id = r.user_id
WHERE r.rn = 1
  AND r.event_type <> 'cancel'
  AND h.n_downgrades >= 1
  AND r.monthly_amount < 0.5 * h.max_amount
  AND h.days_span >= 60
ORDER BY days_as_subscriber DESC, r.user_id;
