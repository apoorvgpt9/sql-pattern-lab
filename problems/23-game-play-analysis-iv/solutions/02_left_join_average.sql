-- Approach 2: one row per player (their first login), LEFT JOINed to the row exactly one day later.
-- The flag (match found / not found) is 1 or 0 per player, and its AVG is the fraction. Because the
-- LEFT JOIN keeps every player, the denominator is automatically "all players".
SELECT ROUND(AVG(a.player_id IS NOT NULL), 2) AS fraction
FROM (SELECT player_id, MIN(event_date) AS first_login
        FROM Activity
       GROUP BY player_id) f
LEFT JOIN Activity a
  ON  a.player_id  = f.player_id
  AND a.event_date = DATE_ADD(f.first_login, INTERVAL 1 DAY);
