-- breaks: edge_same_day_latest
-- MISTAKE: "latest event" as a join back on MAX(event_date). With two events on the last day both
-- rows come back, and the WHERE filters then pick whichever row passes - here the earlier same-day
-- downgrade - so users whose real latest event (higher event_id) fails the rules are reported.
WITH last_day AS (
  SELECT user_id, MAX(event_date) AS last_date, MIN(event_date) AS first_date,
         MAX(monthly_amount) AS max_amount, SUM(event_type = 'downgrade') AS n_downgrades
  FROM subscription_events
  GROUP BY user_id
)
SELECT e.user_id, e.plan_name AS current_plan, e.monthly_amount AS current_monthly_amount,
       l.max_amount AS max_historical_amount,
       DATEDIFF(l.last_date, l.first_date) AS days_as_subscriber
FROM subscription_events e
JOIN last_day l ON l.user_id = e.user_id AND e.event_date = l.last_date
WHERE e.event_type <> 'cancel'
  AND l.n_downgrades >= 1
  AND e.monthly_amount < 0.5 * l.max_amount
  AND DATEDIFF(l.last_date, l.first_date) >= 60
ORDER BY days_as_subscriber DESC, e.user_id;
