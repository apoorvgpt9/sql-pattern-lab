-- Nobody qualifies: each user fails exactly one rule.
INSERT INTO subscription_events (event_id, user_id, event_date, event_type, plan_name, monthly_amount) VALUES
  (1, 1, '2024-01-01', 'start',     'premium', 30.00),
  (2, 1, '2024-02-01', 'downgrade', 'basic',   10.00),
  (3, 1, '2024-04-01', 'cancel',    NULL,       0.00),  -- user 1: latest is a cancel
  (4, 2, '2024-01-01', 'start',     'premium', 30.00),
  (5, 2, '2024-01-31', 'downgrade', 'basic',   10.00),  -- user 2: only 30 days
  (6, 3, '2024-05-01', 'start',     'basic',   10.00);  -- user 3: one event, 0 days, no downgrade

-- expect-empty: user 1 ends with a cancel; user 2 spans 30 days; user 3 has no downgrade and 0 days
