-- Approach 3 (optimal): collapse to one row per day first, then a ROWS window over the daily totals.
-- With one row per day and no date gaps (spec), "6 rows before" is "6 days before".
-- day_no >= 7 keeps only days that have six earlier days.
WITH daily AS (
  SELECT visited_on, SUM(amount) AS day_total
  FROM Customer
  GROUP BY visited_on
),
windowed AS (
  SELECT visited_on,
         SUM(day_total) OVER (ORDER BY visited_on ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS amount,
         ROW_NUMBER()   OVER (ORDER BY visited_on)                                          AS day_no
  FROM daily
)
SELECT visited_on, amount, ROUND(amount / 7, 2) AS average_amount
FROM windowed
WHERE day_no >= 7
ORDER BY visited_on;
