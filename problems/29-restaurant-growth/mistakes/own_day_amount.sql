-- breaks: edge_typical, edge_exactly_seven_days, edge_rounding_month_boundary, edge_ordering
-- MISTAKE: Reporting the day's own total in the amount column. The spec's amount is the 7-day window total.
WITH daily AS (SELECT visited_on, SUM(amount) AS day_total FROM Customer GROUP BY visited_on),
windowed AS (
  SELECT visited_on, day_total,
         SUM(day_total) OVER (ORDER BY visited_on ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS window_total,
         ROW_NUMBER() OVER (ORDER BY visited_on) AS day_no
  FROM daily
)
SELECT visited_on, day_total AS amount, ROUND(window_total / 7, 2) AS average_amount
FROM windowed WHERE day_no >= 7 ORDER BY visited_on;
