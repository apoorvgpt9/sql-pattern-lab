-- Boundary of the amount rule: "below half" is strict. Exactly half does not qualify.
INSERT INTO subscription_events (event_id, user_id, event_date, event_type, plan_name, monthly_amount) VALUES
  (1, 1, '2024-01-01', 'start',     'premium',  30.00),
  (2, 1, '2024-03-15', 'downgrade', 'standard', 15.00),  -- 15.00 is not < 0.5 * 30 = 15.00
  (3, 2, '2024-01-01', 'start',     'premium',  30.00),
  (4, 2, '2024-03-15', 'downgrade', 'basic',    14.99);  -- 14.99 < 15.00

-- expect: 2,basic,14.99,30.00,74 | 14.99 < 0.5 * 30.00 = 15.000; DATEDIFF('2024-03-15', '2024-01-01') = 74
