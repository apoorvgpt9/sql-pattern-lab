-- breaks: edge_typical, edge_exactly_seven_days, edge_fewer_than_seven_days, edge_ordering
-- MISTAKE: No cut-off for the first six days: the window just has fewer rows there, and those partial windows are returned.
WITH daily AS (SELECT visited_on, SUM(amount) AS day_total FROM Customer GROUP BY visited_on)
SELECT visited_on,
       SUM(day_total) OVER (ORDER BY visited_on ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS amount,
       ROUND(SUM(day_total) OVER (ORDER BY visited_on ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) / 7, 2) AS average_amount
FROM daily
ORDER BY visited_on;
