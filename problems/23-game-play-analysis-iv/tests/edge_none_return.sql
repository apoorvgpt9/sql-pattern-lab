-- Nobody returns the next day: the fraction is 0.00, not NULL. Player 3 returns, but after a gap.
INSERT INTO Activity (player_id, device_id, event_date, games_played) VALUES
  (1, 1, '2020-05-01', 1),
  (2, 1, '2020-05-01', 1),
  (3, 1, '2020-05-01', 1),
  (3, 1, '2020-05-03', 1);

-- expect: 0.00 | 3 players, none with a row on first_login + 1: 0 / 3 = 0.00 (a conditional SUM with no ELSE would give NULL)
