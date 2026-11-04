-- Output order: streak_length DESC comes before user_id ASC. User 2 (6 days) must precede
-- user 1 (5 days) even though 1 < 2. Rows are inserted in scrambled order.
INSERT INTO activity (user_id, action_date, action) VALUES
  (1, '2024-08-03', 'ping'), (2, '2024-08-06', 'pong'), (1, '2024-08-01', 'ping'),
  (2, '2024-08-01', 'pong'), (1, '2024-08-05', 'ping'), (2, '2024-08-03', 'pong'),
  (1, '2024-08-02', 'ping'), (2, '2024-08-05', 'pong'), (1, '2024-08-04', 'ping'),
  (2, '2024-08-02', 'pong'), (2, '2024-08-04', 'pong');

-- expect: 2,pong,6,2024-08-01,2024-08-06 | 6 days: longest, so first despite the higher user_id
-- expect: 1,ping,5,2024-08-01,2024-08-05 | 5 days
