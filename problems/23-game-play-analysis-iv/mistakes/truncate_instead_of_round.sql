-- breaks: edge_later_consecutive, edge_date_boundaries, edge_rounding_half
-- MISTAKE: TRUNCATE(x, 2) cuts the digits off instead of rounding: 2/3 gives 0.66 and 1/8 gives 0.12.
WITH x AS (
  SELECT event_date,
         ROW_NUMBER() OVER w AS rn,
         LEAD(event_date) OVER w AS next_date
  FROM Activity
  WINDOW w AS (PARTITION BY player_id ORDER BY event_date)
)
SELECT TRUNCATE(AVG(CASE WHEN DATEDIFF(next_date, event_date) = 1 THEN 1 ELSE 0 END), 2) AS fraction
FROM x WHERE rn = 1;
