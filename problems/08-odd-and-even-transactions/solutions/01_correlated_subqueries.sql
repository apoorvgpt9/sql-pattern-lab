-- Approach 1 (brute force): list the distinct dates, then ask two questions per date.
-- Natural first attempt: "for each day, sum the odd ones; for each day, sum the even ones".
-- COALESCE turns the NULL of an empty SUM into 0. MOD(x, 2) <> 0 is true for negative odd numbers too.
SELECT
  d.transaction_date,
  COALESCE((SELECT SUM(t.amount) FROM transactions t
             WHERE t.transaction_date = d.transaction_date AND MOD(t.amount, 2) <> 0), 0) AS odd_sum,
  COALESCE((SELECT SUM(t.amount) FROM transactions t
             WHERE t.transaction_date = d.transaction_date AND MOD(t.amount, 2) = 0), 0)  AS even_sum
FROM (SELECT DISTINCT transaction_date FROM transactions) d
ORDER BY d.transaction_date;
