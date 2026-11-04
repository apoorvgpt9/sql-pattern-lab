-- Approach 1 (brute force): three separate reads. (a) each player's first login date; (b) the number
-- of players whose activity includes first_login + 1 day, found by joining Activity back to (a);
-- (c) the number of all distinct players, by a scalar subquery. The ratio is rounded to 2 decimals.
SELECT ROUND(
         COUNT(DISTINCT a.player_id)
         / (SELECT COUNT(DISTINCT player_id) FROM Activity),
       2) AS fraction
FROM (SELECT player_id, MIN(event_date) AS first_login
        FROM Activity
       GROUP BY player_id) f
JOIN Activity a
  ON  a.player_id  = f.player_id
  AND a.event_date = DATE_ADD(f.first_login, INTERVAL 1 DAY);
