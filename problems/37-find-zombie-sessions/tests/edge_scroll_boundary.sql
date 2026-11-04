-- Boundary of the scroll rule: at least 5. Both sessions belong to user 7, so grouping by user
-- instead of session merges them.
INSERT INTO app_events (event_id, user_id, event_timestamp, event_type, session_id, event_value) VALUES
  (1,  7, '2024-04-01 07:00:00', 'app_open',  's4', NULL),
  (2,  7, '2024-04-01 07:10:00', 'scroll',    's4', 50),
  (3,  7, '2024-04-01 07:20:00', 'scroll',    's4', 50),
  (4,  7, '2024-04-01 07:30:00', 'scroll',    's4', 50),
  (5,  7, '2024-04-01 07:40:00', 'scroll',    's4', 50),
  (6,  7, '2024-04-01 07:45:00', 'app_close', 's4', NULL),  -- s4: 45 min but only 4 scrolls (6 events)
  (7,  7, '2024-04-01 08:00:00', 'scroll',    's5', 50),
  (8,  7, '2024-04-01 08:10:00', 'scroll',    's5', 50),
  (9,  7, '2024-04-01 08:20:00', 'scroll',    's5', 50),
  (10, 7, '2024-04-01 08:30:00', 'scroll',    's5', 50),
  (11, 7, '2024-04-01 08:45:00', 'scroll',    's5', 50);   -- s5: 45 min, exactly 5 scrolls

-- expect: s5,7,45,5 | 08:00 -> 08:45 = 45 > 30; 5 scrolls >= 5; no clicks; s4 has 4 scrolls
