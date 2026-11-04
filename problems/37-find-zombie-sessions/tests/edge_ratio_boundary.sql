-- Boundary of the click-to-scroll ratio: strictly below 0.20. MySQL: 1/5 = 0.2000, 1/6 = 0.1667.
INSERT INTO app_events (event_id, user_id, event_timestamp, event_type, session_id, event_value) VALUES
  (1,  1, '2024-02-01 09:00:00', 'scroll', 'r1', 100),
  (2,  1, '2024-02-01 09:05:00', 'scroll', 'r1', 100),
  (3,  1, '2024-02-01 09:10:00', 'scroll', 'r1', 100),
  (4,  1, '2024-02-01 09:15:00', 'scroll', 'r1', 100),
  (5,  1, '2024-02-01 09:20:00', 'click',  'r1', NULL),
  (6,  1, '2024-02-01 09:35:00', 'scroll', 'r1', 100),   -- r1: 5 scrolls, 1 click: 1/5 = 0.2000, not < 0.20
  (7,  2, '2024-02-01 10:00:00', 'scroll', 'r2', 100),
  (8,  2, '2024-02-01 10:05:00', 'scroll', 'r2', 100),
  (9,  2, '2024-02-01 10:10:00', 'scroll', 'r2', 100),
  (10, 2, '2024-02-01 10:15:00', 'scroll', 'r2', 100),
  (11, 2, '2024-02-01 10:20:00', 'click',  'r2', NULL),
  (12, 2, '2024-02-01 10:25:00', 'scroll', 'r2', 100),
  (13, 2, '2024-02-01 10:40:00', 'scroll', 'r2', 100);   -- r2: 6 scrolls, 1 click: 1/6 = 0.1667 < 0.20

-- expect: r2,2,40,6 | 10:00 -> 10:40 = 40 > 30; 6 scrolls; 1/6 = 0.1667 < 0.20 (r1 has exactly 1/5 = 0.2000)
