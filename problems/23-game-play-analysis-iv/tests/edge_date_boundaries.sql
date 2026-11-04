-- "The day after" across month, year and leap-day boundaries.
-- 1: Jan 31 -> Feb 1 (yes). 2: Dec 31 -> Jan 1 (yes). 3: Feb 28 -> Feb 29 in a leap year (yes).
-- 4: Feb 28 -> Mar 1 in a non-leap year (yes). 5: Feb 28 -> Mar 1 in a leap year (NO: Feb 29 was skipped).
-- 6: a single login.
INSERT INTO Activity (player_id, device_id, event_date, games_played) VALUES
  (1, 1, '2023-01-31', 1), (1, 1, '2023-02-01', 1),
  (2, 1, '2022-12-31', 1), (2, 1, '2023-01-01', 1),
  (3, 1, '2024-02-28', 1), (3, 1, '2024-02-29', 1),
  (4, 1, '2023-02-28', 1), (4, 1, '2023-03-01', 1),
  (5, 1, '2024-02-28', 1), (5, 1, '2024-03-01', 1),
  (6, 1, '2023-05-10', 1);

-- expect: 0.67 | 6 players; 1, 2, 3 and 4 have a row on first_login + 1 day, 5 and 6 do not: 4 / 6 = 0.6667 -> 0.67
