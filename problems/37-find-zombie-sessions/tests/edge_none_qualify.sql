-- Nobody qualifies: e1 bought something; e2 is too short.
INSERT INTO app_events (event_id, user_id, event_timestamp, event_type, session_id, event_value) VALUES
  (1,  1, '2024-07-01 10:00:00', 'scroll',   'e1', 5),
  (2,  1, '2024-07-01 10:10:00', 'scroll',   'e1', 5),
  (3,  1, '2024-07-01 10:20:00', 'purchase', 'e1', 0),     -- a zero-value purchase is still a purchase
  (4,  1, '2024-07-01 10:30:00', 'scroll',   'e1', 5),
  (5,  1, '2024-07-01 10:40:00', 'scroll',   'e1', 5),
  (6,  1, '2024-07-01 10:50:00', 'scroll',   'e1', 5),
  (7,  2, '2024-07-01 11:00:00', 'scroll',   'e2', 5),
  (8,  2, '2024-07-01 11:05:00', 'scroll',   'e2', 5),
  (9,  2, '2024-07-01 11:10:00', 'scroll',   'e2', 5),
  (10, 2, '2024-07-01 11:15:00', 'scroll',   'e2', 5),
  (11, 2, '2024-07-01 11:20:00', 'scroll',   'e2', 5);     -- e2: 20 min

-- expect-empty: e1 has a purchase (amount 0 still counts); e2 lasts 20 minutes
