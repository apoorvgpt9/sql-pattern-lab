-- breaks: edge_none_return
-- MISTAKE: SUM(CASE WHEN returned THEN 1 END) with no ELSE. When no player returned, every CASE is NULL, SUM
-- of only NULLs is NULL, and the fraction is NULL instead of 0.00.
WITH x AS (
  SELECT event_date,
         ROW_NUMBER() OVER w AS rn,
         LEAD(event_date) OVER w AS next_date
  FROM Activity
  WINDOW w AS (PARTITION BY player_id ORDER BY event_date)
)
SELECT ROUND(SUM(CASE WHEN DATEDIFF(next_date, event_date) = 1 THEN 1 END) / COUNT(*), 2) AS fraction
FROM x WHERE rn = 1;
