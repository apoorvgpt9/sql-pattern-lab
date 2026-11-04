-- 1 of 8 players returns: 1 / 8 = 0.125 exactly. MySQL computes the quotient as the exact decimal 0.1250
-- and ROUND rounds the half away from zero: 0.13 (TRUNCATE would give 0.12).
INSERT INTO Activity (player_id, device_id, event_date, games_played) VALUES
  (1, 1, '2021-01-01', 1), (1, 1, '2021-01-02', 1),
  (2, 1, '2021-01-01', 1),
  (3, 1, '2021-01-01', 1),
  (4, 1, '2021-01-01', 1),
  (5, 1, '2021-01-01', 1),
  (6, 1, '2021-01-01', 1),
  (7, 1, '2021-01-01', 1),
  (8, 1, '2021-01-01', 1);

-- expect: 0.13 | 1 / 8 = 0.1250, rounded half up to 2 decimals
