-- Output order: days_as_subscriber DESC, then user_id ASC. Users 1 and 3 tie on 70 days.
-- Rows are inserted in scrambled order.
INSERT INTO subscription_events (event_id, user_id, event_date, event_type, plan_name, monthly_amount) VALUES
  (6, 3, '2024-03-11', 'downgrade', 'basic',   10.00),
  (1, 1, '2024-01-01', 'start',     'premium', 30.00),
  (4, 2, '2024-03-31', 'downgrade', 'basic',   10.00),
  (5, 3, '2024-01-01', 'start',     'premium', 30.00),
  (3, 2, '2024-01-01', 'start',     'premium', 30.00),
  (2, 1, '2024-03-11', 'downgrade', 'basic',   10.00);

-- expect: 2,basic,10.00,30.00,90 | DATEDIFF('2024-03-31', '2024-01-01') = 90: longest tenure first
-- expect: 1,basic,10.00,30.00,70 | DATEDIFF('2024-03-11', '2024-01-01') = 70; ties with user 3, lower id first
-- expect: 3,basic,10.00,30.00,70 | DATEDIFF('2024-03-11', '2024-01-01') = 70
