-- breaks: edge_typical, edge_later_consecutive, edge_date_boundaries, edge_rounding_half, edge_none_return
-- MISTAKE: both counts come from the joined set (an INNER JOIN to the next-day row), so the denominator
-- is "players who returned" and the fraction is always 1.00 (or NULL when nobody returned). The spec divides by ALL players.
SELECT ROUND(COUNT(DISTINCT a.player_id) / COUNT(DISTINCT f.player_id), 2) AS fraction
FROM (SELECT player_id, MIN(event_date) AS first_login FROM Activity GROUP BY player_id) f
JOIN Activity a
  ON a.player_id = f.player_id AND a.event_date = DATE_ADD(f.first_login, INTERVAL 1 DAY);
