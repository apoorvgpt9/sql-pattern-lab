-- breaks: edge_typical, edge_exactly_seven_days
-- MISTAKE: A ROWS window directly on the customer rows. 'Six rows before' is six VISITS, not six days; days with several
-- customers throw the window off, and each day produces several output rows.
SELECT visited_on, amount, ROUND(amount / 7, 2) AS average_amount
FROM (
  SELECT visited_on,
         SUM(amount) OVER (ORDER BY visited_on ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS amount,
         ROW_NUMBER() OVER (ORDER BY visited_on) AS rn
  FROM Customer
) t
WHERE rn >= 7
ORDER BY visited_on;
