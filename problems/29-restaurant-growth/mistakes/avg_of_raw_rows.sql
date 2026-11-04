-- breaks: edge_typical
-- MISTAKE: AVG over the customer rows of the window instead of window total / 7. When a day has several customers the
-- average per visit is not the average per day (the spec divides the 7-day total by 7).
SELECT DISTINCT visited_on, amount, ROUND(avg_visit, 2) AS average_amount
FROM (
  SELECT visited_on,
         SUM(amount) OVER w AS amount,
         AVG(amount) OVER w AS avg_visit
  FROM Customer
  WINDOW w AS (ORDER BY visited_on RANGE BETWEEN INTERVAL 6 DAY PRECEDING AND CURRENT ROW)
) t
WHERE visited_on >= (SELECT MIN(visited_on) + INTERVAL 6 DAY FROM Customer)
ORDER BY visited_on;
