-- ASSUMPTION test (README "Assumptions"): duration is whole minutes, TIMESTAMPDIFF(MINUTE, ...),
-- which truncates, and the rule is strictly MORE than 30.
--   d1: 30 min 59 s -> 30, not > 30.   d3: exactly 30:00 -> 30, not > 30.   d2: 31:00 -> 31.
INSERT INTO app_events (event_id, user_id, event_timestamp, event_type, session_id, event_value) VALUES
  (1,  1, '2024-03-01 08:00:00', 'scroll', 'd1', 10),
  (2,  1, '2024-03-01 08:10:00', 'scroll', 'd1', 10),
  (3,  1, '2024-03-01 08:20:00', 'scroll', 'd1', 10),
  (4,  1, '2024-03-01 08:25:00', 'scroll', 'd1', 10),
  (5,  1, '2024-03-01 08:30:59', 'scroll', 'd1', 10),
  (6,  2, '2024-03-01 09:00:00', 'scroll', 'd2', 10),
  (7,  2, '2024-03-01 09:10:00', 'scroll', 'd2', 10),
  (8,  2, '2024-03-01 09:20:00', 'scroll', 'd2', 10),
  (9,  2, '2024-03-01 09:25:00', 'scroll', 'd2', 10),
  (10, 2, '2024-03-01 09:31:00', 'scroll', 'd2', 10),
  (11, 3, '2024-03-01 10:00:00', 'scroll', 'd3', 10),
  (12, 3, '2024-03-01 10:10:00', 'scroll', 'd3', 10),
  (13, 3, '2024-03-01 10:20:00', 'scroll', 'd3', 10),
  (14, 3, '2024-03-01 10:25:00', 'scroll', 'd3', 10),
  (15, 3, '2024-03-01 10:30:00', 'scroll', 'd3', 10);

-- expect: d2,2,31,5 | TIMESTAMPDIFF(MINUTE, 09:00:00, 09:31:00) = 31 > 30; d1 = 30 (30:59 truncates), d3 = 30
