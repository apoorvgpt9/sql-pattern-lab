-- Only the day after the FIRST login counts. Player 1 has two consecutive days later on (01-03, 01-04)
-- but nothing on 01-02. Player 3 has three consecutive days and is counted once.
INSERT INTO Activity (player_id, device_id, event_date, games_played) VALUES
  (1, 1, '2020-01-01', 1),
  (1, 1, '2020-01-03', 1),
  (1, 1, '2020-01-04', 1),
  (2, 1, '2020-01-01', 1),
  (2, 1, '2020-01-02', 1),
  (3, 1, '2020-02-01', 1),
  (3, 1, '2020-02-02', 1),
  (3, 1, '2020-02-03', 1);

-- expect: 0.67 | 3 players; 2 and 3 return the day after their first login (3 counted once although it has more consecutive days), 1 does not: 2 / 3 = 0.6667 -> 0.67
