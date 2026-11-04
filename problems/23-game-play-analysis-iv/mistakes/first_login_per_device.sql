-- breaks: edge_typical
-- MISTAKE: finds the first login per (player, device) instead of per player. A player who plays on a second
-- device the next day (player 4) is not counted, and a player with several devices would be counted several times.
SELECT ROUND(COUNT(DISTINCT a.player_id) / (SELECT COUNT(DISTINCT player_id) FROM Activity), 2) AS fraction
FROM (SELECT player_id, device_id, MIN(event_date) AS first_login
        FROM Activity GROUP BY player_id, device_id) f
JOIN Activity a
  ON a.player_id = f.player_id AND a.device_id = f.device_id
 AND a.event_date = DATE_ADD(f.first_login, INTERVAL 1 DAY);
