-- Approach 2: one pass, one sort. Every per-user fact is a window over the same partition and
-- order, framed over the whole partition, so the latest row (rn = 1) carries the history
-- aggregates with it. No second scan, no join - but the aggregates are computed for EVERY row and
-- then all rows except one per user are thrown away (README section 5).
WITH per_event AS (
  SELECT user_id, event_date, event_type, plan_name, monthly_amount,
         ROW_NUMBER()                  OVER w     AS rn,
         MAX(monthly_amount)           OVER w_all AS max_amount,
         MIN(event_date)               OVER w_all AS first_date,
         SUM(event_type = 'downgrade') OVER w_all AS n_downgrades
  FROM subscription_events
  WINDOW w     AS (PARTITION BY user_id ORDER BY event_date DESC, event_id DESC),
         w_all AS (w ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING)
)
SELECT user_id,
       plan_name                       AS current_plan,
       monthly_amount                  AS current_monthly_amount,
       max_amount                      AS max_historical_amount,
       DATEDIFF(event_date, first_date) AS days_as_subscriber
FROM per_event
WHERE rn = 1                           -- the latest event: its date is the user's last date
  AND event_type <> 'cancel'
  AND n_downgrades >= 1
  AND monthly_amount < 0.5 * max_amount
  AND DATEDIFF(event_date, first_date) >= 60
ORDER BY days_as_subscriber DESC, user_id;
