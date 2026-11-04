-- breaks: edge_negative_and_zero
-- MISTAKE: odd = "amount % 2 = 1". In MySQL the remainder takes the sign of the dividend:
-- -3 % 2 is -1, so negative odd amounts are classified as neither odd nor even and silently vanish.
SELECT
  transaction_date,
  SUM(CASE WHEN amount % 2 = 1 THEN amount ELSE 0 END) AS odd_sum,
  SUM(CASE WHEN amount % 2 = 0 THEN amount ELSE 0 END) AS even_sum
FROM transactions
GROUP BY transaction_date
ORDER BY transaction_date;
