-- NULLs: event_value is irrelevant. A purchase with a NULL amount is still a purchase.
INSERT INTO app_events (event_id, user_id, event_timestamp, event_type, session_id, event_value) VALUES
  (1,  1, '2024-05-01 12:00:00', 'scroll',   'n1', NULL),
  (2,  1, '2024-05-01 12:10:00', 'scroll',   'n1', NULL),
  (3,  1, '2024-05-01 12:20:00', 'scroll',   'n1', NULL),
  (4,  1, '2024-05-01 12:30:00', 'scroll',   'n1', NULL),
  (5,  1, '2024-05-01 12:35:00', 'purchase', 'n1', NULL),   -- n1: a purchase (amount unknown)
  (6,  1, '2024-05-01 12:40:00', 'scroll',   'n1', NULL),
  (7,  2, '2024-05-01 13:00:00', 'scroll',   'n2', NULL),
  (8,  2, '2024-05-01 13:10:00', 'scroll',   'n2', 900),
  (9,  2, '2024-05-01 13:20:00', 'scroll',   'n2', NULL),
  (10, 2, '2024-05-01 13:30:00', 'scroll',   'n2', 900),
  (11, 2, '2024-05-01 13:33:00', 'scroll',   'n2', NULL);   -- n2: 33 min, 5 scrolls (pixels partly unknown)

-- expect: n2,2,33,5 | 13:00 -> 13:33 = 33 > 30; 5 scrolls counted by event_type, whatever event_value is
