-- breaks: edge_later_consecutive
-- MISTAKE: counts a player if ANY two consecutive days exist in their history, not specifically the day after
-- the FIRST login. Player 1 (01-01, then 01-03 and 01-04) is wrongly counted.
WITH x AS (
  SELECT player_id, event_date,
         LEAD(event_date) OVER (PARTITION BY player_id ORDER BY event_date) AS next_date
  FROM Activity
)
SELECT ROUND(COUNT(DISTINCT CASE WHEN DATEDIFF(next_date, event_date) = 1 THEN player_id END)
             / COUNT(DISTINCT player_id), 2) AS fraction
FROM x;
