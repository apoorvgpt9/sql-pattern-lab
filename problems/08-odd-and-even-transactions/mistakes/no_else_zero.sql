-- breaks: edge_one_side_missing, edge_nulls, edge_negative_and_zero
-- MISTAKE: CASE without ELSE 0. SUM over only-NULL inputs is NULL, so a day with one parity
-- missing shows NULL instead of 0.
SELECT
  transaction_date,
  SUM(CASE WHEN MOD(amount, 2) <> 0 THEN amount END) AS odd_sum,
  SUM(CASE WHEN MOD(amount, 2) =  0 THEN amount END) AS even_sum
FROM transactions
GROUP BY transaction_date
ORDER BY transaction_date;
