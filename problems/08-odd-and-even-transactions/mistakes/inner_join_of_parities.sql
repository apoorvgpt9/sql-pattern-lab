-- breaks: edge_one_side_missing, edge_nulls, edge_negative_and_zero
-- MISTAKE: sum each parity separately, then INNER JOIN. A day that lacks either parity has no row
-- on one side of the join and disappears from the output entirely.
WITH odd_day AS (
  SELECT transaction_date, SUM(amount) AS s FROM transactions WHERE MOD(amount, 2) <> 0 GROUP BY transaction_date
),
even_day AS (
  SELECT transaction_date, SUM(amount) AS s FROM transactions WHERE MOD(amount, 2) = 0 GROUP BY transaction_date
)
SELECT o.transaction_date, o.s AS odd_sum, e.s AS even_sum
FROM odd_day o
JOIN even_day e ON e.transaction_date = o.transaction_date
ORDER BY o.transaction_date;
