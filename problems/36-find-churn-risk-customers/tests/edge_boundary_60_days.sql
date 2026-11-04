-- Boundary of the tenure rule: exactly 60 days qualifies (>= 60), 59 does not.
-- Same calendar dates, different years: 2024 is a leap year, 2023 is not.
INSERT INTO subscription_events (event_id, user_id, event_date, event_type, plan_name, monthly_amount) VALUES
  (1, 1, '2024-01-01', 'start',     'premium', 30.00),
  (2, 1, '2024-03-01', 'downgrade', 'basic',   10.00),  -- 31 (Jan) + 29 (Feb 2024) = 60 days
  (3, 2, '2023-01-01', 'start',     'premium', 30.00),
  (4, 2, '2023-03-01', 'downgrade', 'basic',   10.00);  -- 31 + 28 (Feb 2023) = 59 days

-- expect: 1,basic,10.00,30.00,60 | DATEDIFF('2024-03-01', '2024-01-01') = 60 >= 60; 10 < 15.0
