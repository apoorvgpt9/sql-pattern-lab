-- breaks: edge_date_boundaries
-- MISTAKE: first_login + 1 treats the date as the number 20230131 and adds 1. That is right inside a month
-- (20160301 + 1 = 20160302 compares equal to the date 2016-03-02) and wrong at every month end
-- (20230131 + 1 = 20230132 is not a date). It passes ordinary data and fails on the month boundary.
SELECT ROUND(COUNT(DISTINCT a.player_id) / (SELECT COUNT(DISTINCT player_id) FROM Activity), 2) AS fraction
FROM (SELECT player_id, MIN(event_date) AS first_login FROM Activity GROUP BY player_id) f
JOIN Activity a
  ON a.player_id = f.player_id AND a.event_date = f.first_login + 1;
