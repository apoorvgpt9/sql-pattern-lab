-- Five players: two come back the day after their first login (one of them on another device),
-- one never comes back, one comes back after a gap of years, one on the second day after.
INSERT INTO Activity (player_id, device_id, event_date, games_played) VALUES
  (1, 2, '2016-03-01', 5),
  (1, 2, '2016-03-02', 6),
  (2, 3, '2017-06-25', 1),
  (3, 1, '2016-03-02', 0),
  (3, 4, '2018-07-03', 5),
  (4, 1, '2019-01-10', 2),
  (4, 2, '2019-01-11', 3),  -- day after the first login, on a different device: still counts
  (5, 1, '2019-01-10', 1),
  (5, 1, '2019-01-12', 1);  -- two days after: not "the day after"

-- expect: 0.40 | 5 players; players 1 and 4 have a row exactly one day after their first login: 2 / 5 = 0.40
