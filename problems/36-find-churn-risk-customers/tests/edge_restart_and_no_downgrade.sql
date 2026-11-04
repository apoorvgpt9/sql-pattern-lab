-- A cancel in the MIDDLE of history (NULL plan_name, amount 0) does not disqualify anyone; only
-- the latest event matters. User 1 dropped to a cheaper plan by cancelling and restarting, with
-- no 'downgrade' event, so user 1 fails the downgrade rule.
INSERT INTO subscription_events (event_id, user_id, event_date, event_type, plan_name, monthly_amount) VALUES
  (1, 1, '2024-01-01', 'start',     'premium', 40.00),
  (2, 1, '2024-02-01', 'cancel',    NULL,       0.00),
  (3, 1, '2024-03-15', 'start',     'basic',   10.00),  -- user 1: 10 < 20 and 74 days, but no downgrade
  (4, 2, '2024-01-01', 'start',     'premium', 40.00),
  (5, 2, '2024-02-01', 'cancel',    NULL,       0.00),  -- user 2: cancelled once, then came back
  (6, 2, '2024-02-15', 'start',     'premium', 40.00),
  (7, 2, '2024-03-20', 'downgrade', 'basic',   10.00);

-- expect: 2,basic,10.00,40.00,79 | latest is a downgrade, 10 < 20.0, DATEDIFF('2024-03-20', '2024-01-01') = 79; the earlier cancel is irrelevant
