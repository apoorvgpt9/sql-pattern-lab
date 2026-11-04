-- Output order: scroll_count DESC first. Session 'b' (6 scrolls) precedes 'a' (5) although 'a' < 'b'.
INSERT INTO app_events (event_id, user_id, event_timestamp, event_type, session_id, event_value) VALUES
  (1,  1, '2024-06-01 10:00:00', 'scroll', 'a', 1),
  (2,  1, '2024-06-01 10:10:00', 'scroll', 'a', 1),
  (3,  1, '2024-06-01 10:20:00', 'scroll', 'a', 1),
  (4,  1, '2024-06-01 10:30:00', 'scroll', 'a', 1),
  (5,  1, '2024-06-01 10:40:00', 'scroll', 'a', 1),
  (6,  2, '2024-06-01 11:00:00', 'scroll', 'b', 1),
  (7,  2, '2024-06-01 11:10:00', 'scroll', 'b', 1),
  (8,  2, '2024-06-01 11:20:00', 'scroll', 'b', 1),
  (9,  2, '2024-06-01 11:30:00', 'scroll', 'b', 1),
  (10, 2, '2024-06-01 11:40:00', 'scroll', 'b', 1),
  (11, 2, '2024-06-01 11:50:00', 'scroll', 'b', 1);

-- expect: b,2,50,6 | 11:00 -> 11:50 = 50; 6 scrolls: most scrolls first
-- expect: a,1,40,5 | 10:00 -> 10:40 = 40; 5 scrolls
