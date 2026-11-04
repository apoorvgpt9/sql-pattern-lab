-- Same-day events: the latest event is the one with the higher event_id (rules.ties).
-- Users 1 and 2: the latest row FAILS the test while the earlier same-day row would pass, so
-- "join back on MAX(event_date)" (which keeps both rows) wrongly reports them.
INSERT INTO subscription_events (event_id, user_id, event_date, event_type, plan_name, monthly_amount) VALUES
  (1, 1, '2024-01-01', 'start',     'premium',  40.00),
  (2, 1, '2024-03-15', 'downgrade', 'basic',    10.00),
  (3, 1, '2024-03-15', 'upgrade',   'standard', 25.00),  -- user 1's latest: 25 is not < 20
  (4, 2, '2024-01-01', 'start',     'premium',  40.00),
  (5, 2, '2024-03-15', 'downgrade', 'basic',    10.00),
  (6, 2, '2024-03-15', 'cancel',    NULL,        0.00),  -- user 2's latest: a cancel
  (7, 3, '2024-01-01', 'start',     'premium',  40.00),
  (8, 3, '2024-03-20', 'upgrade',   'standard', 30.00),
  (9, 3, '2024-03-20', 'downgrade', 'basic',    15.00);  -- user 3's latest (id 9): basic 15

-- expect: 3,basic,15.00,40.00,79 | latest = event 9 (higher id on 03-20): 15 < 0.5 * 40 = 20.0; DATEDIFF('2024-03-20', '2024-01-01') = 79
