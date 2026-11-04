-- Typical: a zombie session that crosses midnight and starts/ends with app_open/app_close
-- (they count toward duration), and a session that would qualify but contains a purchase.
INSERT INTO app_events (event_id, user_id, event_timestamp, event_type, session_id, event_value) VALUES
  (1,  1, '2024-01-01 23:50:00', 'app_open',  'a1', NULL),
  (2,  1, '2024-01-01 23:55:00', 'scroll',    'a1', 400),
  (3,  1, '2024-01-02 00:00:00', 'scroll',    'a1', 500),
  (4,  1, '2024-01-02 00:05:00', 'scroll',    'a1', 300),
  (5,  1, '2024-01-02 00:10:00', 'scroll',    'a1', 800),
  (6,  1, '2024-01-02 00:15:00', 'scroll',    'a1', 200),
  (7,  1, '2024-01-02 00:20:00', 'scroll',    'a1', 600),
  (8,  1, '2024-01-02 00:30:00', 'app_close', 'a1', NULL),   -- a1: 23:50 -> 00:30 = 40 min
  (9,  2, '2024-01-03 11:00:00', 'scroll',    'b2', 100),
  (10, 2, '2024-01-03 11:01:00', 'scroll',    'b2', 100),
  (11, 2, '2024-01-03 11:02:00', 'scroll',    'b2', 100),
  (12, 2, '2024-01-03 11:03:00', 'scroll',    'b2', 100),
  (13, 2, '2024-01-03 11:04:00', 'scroll',    'b2', 100),
  (14, 2, '2024-01-03 11:40:00', 'purchase',  'b2', 25);     -- b2: 40 min, 5 scrolls, but bought

-- expect: a1,1,40,6 | TIMESTAMPDIFF(MINUTE, 23:50, 00:30 next day) = 40 > 30; 6 scrolls >= 5; 0 clicks / 6 = 0 < 0.20; no purchase
