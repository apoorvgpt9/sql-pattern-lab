-- Game Play Analysis IV (LeetCode 550): tables for MySQL 8.0. Names mirror the original.
-- The key is (player_id, event_date): a player has at most one row per day, whatever device they used.

CREATE TABLE Activity (
  player_id    INT NOT NULL,
  device_id    INT NOT NULL,
  event_date   DATE NOT NULL,
  games_played INT NOT NULL,
  PRIMARY KEY (player_id, event_date)   -- grain: one row per player per active day
);
