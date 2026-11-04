-- breaks: edge_typical
-- MISTAKE: SUM(DISTINCT amount), copied from COUNT(DISTINCT ...) habits. Two transactions with the
-- same amount on the same day are two transactions; collapsing them under-reports the total.
SELECT
  transaction_date,
  SUM(DISTINCT CASE WHEN MOD(amount, 2) <> 0 THEN amount ELSE 0 END) AS odd_sum,
  SUM(DISTINCT CASE WHEN MOD(amount, 2) =  0 THEN amount ELSE 0 END) AS even_sum
FROM transactions
GROUP BY transaction_date
ORDER BY transaction_date;
