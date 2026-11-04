-- breaks: edge_nulls
-- MISTAKE: "clean the data first" with WHERE amount IS NOT NULL. A day whose only transactions have
-- a NULL amount then has no rows to group, so the day disappears; the spec says one row per date present.
SELECT
  transaction_date,
  SUM(CASE WHEN MOD(amount, 2) <> 0 THEN amount ELSE 0 END) AS odd_sum,
  SUM(CASE WHEN MOD(amount, 2) =  0 THEN amount ELSE 0 END) AS even_sum
FROM transactions
WHERE amount IS NOT NULL
GROUP BY transaction_date
ORDER BY transaction_date;
