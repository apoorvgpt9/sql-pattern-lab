-- breaks: edge_typical, edge_ordering
-- MISTAKE: wrong sort direction. The spec asks for ascending dates; the harness compares in exact order.
SELECT
  transaction_date,
  SUM(CASE WHEN MOD(amount, 2) <> 0 THEN amount ELSE 0 END) AS odd_sum,
  SUM(CASE WHEN MOD(amount, 2) =  0 THEN amount ELSE 0 END) AS even_sum
FROM transactions
GROUP BY transaction_date
ORDER BY transaction_date DESC;
