-- breaks: edge_typical, edge_rounding_month_boundary
-- MISTAKE: Forgetting ROUND: MySQL returns 4 decimals (102.8571), not the 2 the spec asks for.
WITH daily AS (SELECT visited_on, SUM(amount) AS day_total FROM Customer GROUP BY visited_on),
windowed AS (
  SELECT visited_on,
         SUM(day_total) OVER (ORDER BY visited_on ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS amount,
         ROW_NUMBER() OVER (ORDER BY visited_on) AS day_no
  FROM daily
)
SELECT visited_on, amount, amount / 7 AS average_amount
FROM windowed WHERE day_no >= 7 ORDER BY visited_on;
