-- Typical: one row per churn-risk user. All four conditions must hold:
--   latest event not 'cancel'; at least one 'downgrade' ever; latest amount < 0.5 * max amount;
--   DATEDIFF(last event date, first event date) >= 60.
INSERT INTO subscription_events (event_id, user_id, event_date, event_type, plan_name, monthly_amount) VALUES
  (1,  1, '2024-01-01', 'start',     'premium',  30.00),
  (2,  1, '2024-02-15', 'downgrade', 'standard', 20.00),
  (3,  1, '2024-03-20', 'downgrade', 'basic',    10.00),  -- user 1: latest basic 10 < 0.5 * 30 = 15
  (4,  2, '2024-01-01', 'start',     'basic',    10.00),
  (5,  2, '2024-02-01', 'upgrade',   'premium',  30.00),
  (6,  2, '2024-03-15', 'downgrade', 'standard', 20.00),  -- user 2: latest 20 is not < 15 (lowest ever is 10)
  (7,  3, '2024-01-01', 'start',     'premium',  30.00),
  (8,  3, '2024-02-01', 'downgrade', 'basic',    10.00),
  (9,  3, '2024-04-01', 'cancel',    NULL,        0.00),  -- user 3: latest event is a cancel
  (10, 4, '2024-01-01', 'start',     'premium',  40.00),
  (11, 4, '2024-02-01', 'downgrade', 'basic',    10.00),
  (12, 4, '2024-03-10', 'upgrade',   'standard', 15.00);  -- user 4: latest is an upgrade, but a downgrade exists

-- expect: 1,basic,10.00,30.00,79 | 10 < 0.5 * 30 = 15.0; DATEDIFF('2024-03-20', '2024-01-01') = 79 (2024 is a leap year)
-- expect: 4,standard,15.00,40.00,69 | 15 < 0.5 * 40 = 20.0; downgrade on 02-01; DATEDIFF('2024-03-10', '2024-01-01') = 69
