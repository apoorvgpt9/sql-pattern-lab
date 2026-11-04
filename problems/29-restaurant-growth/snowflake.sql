-- UNVERIFIED: Snowflake version of the optimal approach (03). CI cannot run Snowflake.
-- Same shape as MySQL; QUALIFY replaces the day_no subquery layer. Differences are in README section 9.
WITH daily AS (
  SELECT visited_on, SUM(amount) AS day_total
  FROM Customer
  GROUP BY visited_on
),
windowed AS (
  SELECT visited_on,
         SUM(day_total) OVER (ORDER BY visited_on ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS amount
  FROM daily
  QUALIFY ROW_NUMBER() OVER (ORDER BY visited_on) >= 7
)
SELECT visited_on, amount, ROUND(amount / 7, 2) AS average_amount
FROM windowed
ORDER BY visited_on;
