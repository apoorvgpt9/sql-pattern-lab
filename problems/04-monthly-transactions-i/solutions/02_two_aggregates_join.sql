-- Approach 2: one GROUP BY over all rows for the totals, a second GROUP BY over approved rows only, then
-- join the two on the group key. The join must be a LEFT JOIN (groups with no approved row) and NULL-safe
-- (`<=>`) on country, or the NULL-country group never matches itself.
WITH totals AS (
  SELECT DATE_FORMAT(trans_date, '%Y-%m') AS month, country,
         COUNT(*) AS trans_count, SUM(amount) AS trans_total_amount
  FROM Transactions
  GROUP BY DATE_FORMAT(trans_date, '%Y-%m'), country
), approved AS (
  SELECT DATE_FORMAT(trans_date, '%Y-%m') AS month, country,
         COUNT(*) AS approved_count, SUM(amount) AS approved_total_amount
  FROM Transactions
  WHERE state = 'approved'
  GROUP BY DATE_FORMAT(trans_date, '%Y-%m'), country
)
SELECT t.month, t.country, t.trans_count,
       COALESCE(a.approved_count, 0)        AS approved_count,
       t.trans_total_amount,
       COALESCE(a.approved_total_amount, 0) AS approved_total_amount
FROM totals t
LEFT JOIN approved a ON a.month = t.month AND a.country <=> t.country;
