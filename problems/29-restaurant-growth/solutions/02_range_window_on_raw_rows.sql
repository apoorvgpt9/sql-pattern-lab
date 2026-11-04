-- Approach 2: skip the daily pre-aggregation and put a calendar RANGE window straight on the customer rows.
-- RANGE treats all rows of the same day as peers, so every row of a day gets the same 7-day total;
-- DISTINCT then collapses the per-customer duplicates back to one row per day.
-- The first six days are cut by comparing with the earliest date + 6 days (spec: no date gaps).
SELECT DISTINCT visited_on, amount, ROUND(amount / 7, 2) AS average_amount
FROM (
  SELECT visited_on,
         SUM(amount) OVER (ORDER BY visited_on
                           RANGE BETWEEN INTERVAL 6 DAY PRECEDING AND CURRENT ROW) AS amount
  FROM Customer
) t
WHERE visited_on >= (SELECT MIN(visited_on) + INTERVAL 6 DAY FROM Customer)
ORDER BY visited_on;
