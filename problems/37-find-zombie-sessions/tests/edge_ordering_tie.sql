-- Output order on a scroll_count tie: session_id ASC. user_id runs the other way ('m1' has user 1,
-- 'k2' has user 2), so ordering by user_id gives the wrong order.
INSERT INTO app_events (event_id, user_id, event_timestamp, event_type, session_id, event_value) VALUES
  (1,  1, '2024-06-02 10:00:00', 'scroll', 'm1', 1),
  (2,  1, '2024-06-02 10:10:00', 'scroll', 'm1', 1),
  (3,  1, '2024-06-02 10:20:00', 'scroll', 'm1', 1),
  (4,  1, '2024-06-02 10:30:00', 'scroll', 'm1', 1),
  (5,  1, '2024-06-02 10:35:00', 'scroll', 'm1', 1),
  (6,  2, '2024-06-02 11:00:00', 'scroll', 'k2', 1),
  (7,  2, '2024-06-02 11:10:00', 'scroll', 'k2', 1),
  (8,  2, '2024-06-02 11:20:00', 'scroll', 'k2', 1),
  (9,  2, '2024-06-02 11:30:00', 'scroll', 'k2', 1),
  (10, 2, '2024-06-02 11:45:00', 'scroll', 'k2', 1);

-- expect: k2,2,45,5 | 11:00 -> 11:45 = 45; 5 scrolls; ties with m1, 'k2' < 'm1'
-- expect: m1,1,35,5 | 10:00 -> 10:35 = 35; 5 scrolls
