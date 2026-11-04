-- breaks: edge_typical, edge_one_side_missing
-- MISTAKE: classifying by transaction_id instead of by amount (the trigger phrase says "odd and even
-- transactions", which tempts you to look at the transaction's id).
SELECT
  transaction_date,
  SUM(CASE WHEN transaction_id % 2 = 1 THEN amount ELSE 0 END) AS odd_sum,
  SUM(CASE WHEN transaction_id % 2 = 0 THEN amount ELSE 0 END) AS even_sum
FROM transactions
GROUP BY transaction_date
ORDER BY transaction_date;
