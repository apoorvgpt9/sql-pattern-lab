-- breaks: edge_typical, edge_later_consecutive, edge_date_boundaries, edge_rounding_half
-- MISTAKE: divides by the number of Activity ROWS instead of the number of distinct players. A player has
-- one row per active day, so the denominator is inflated.
SELECT ROUND(COUNT(DISTINCT a.player_id) / (SELECT COUNT(*) FROM Activity), 2) AS fraction
FROM (SELECT player_id, MIN(event_date) AS first_login FROM Activity GROUP BY player_id) f
JOIN Activity a
  ON a.player_id = f.player_id AND a.event_date = DATE_ADD(f.first_login, INTERVAL 1 DAY);
