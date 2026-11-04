-- breaks: edge_empty
-- MISTAKE: an aggregate without GROUP BY collapses everything to one row, and on an empty table
-- returns one row of NULLs instead of no rows. (Passing the date through needs ANY_VALUE under
-- ONLY_FULL_GROUP_BY, which is itself a sign the grain is wrong.)
SELECT
  MIN(transaction_date) AS transaction_date,
  SUM(CASE WHEN MOD(amount, 2) <> 0 THEN amount ELSE 0 END) AS odd_sum,
  SUM(CASE WHEN MOD(amount, 2) =  0 THEN amount ELSE 0 END) AS even_sum
FROM transactions;
