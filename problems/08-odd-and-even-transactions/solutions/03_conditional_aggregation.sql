-- Approach 3 (optimal): one pass, one GROUP BY, two conditional sums.
-- ELSE 0 makes the non-matching side contribute 0, so a day with only one parity gets 0 (not NULL).
-- A NULL amount makes both conditions unknown, falls to ELSE 0, and the day still gets its row.
SELECT
  transaction_date,
  SUM(CASE WHEN MOD(amount, 2) <> 0 THEN amount ELSE 0 END) AS odd_sum,
  SUM(CASE WHEN MOD(amount, 2) =  0 THEN amount ELSE 0 END) AS even_sum
FROM transactions
GROUP BY transaction_date
ORDER BY transaction_date;
