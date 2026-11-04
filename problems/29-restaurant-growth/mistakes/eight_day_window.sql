-- breaks: edge_typical, edge_rounding_month_boundary, edge_ordering
-- MISTAKE: Off by one in the frame: 7 PRECEDING plus the current row is an 8-day window.
WITH daily AS (SELECT visited_on, SUM(amount) AS day_total FROM Customer GROUP BY visited_on),
windowed AS (
  SELECT visited_on,
         SUM(day_total) OVER (ORDER BY visited_on ROWS BETWEEN 7 PRECEDING AND CURRENT ROW) AS amount,
         ROW_NUMBER() OVER (ORDER BY visited_on) AS day_no
  FROM daily
)
SELECT visited_on, amount, ROUND(amount / 7, 2) AS average_amount
FROM windowed WHERE day_no >= 7 ORDER BY visited_on;
