-- breaks: edge_null_country
-- MISTAKE: approach 2 with `a.country = t.country`. NULL = NULL is not true, so the NULL-country group never finds its
-- approved counterpart and reports 0 approved even though it has some.
WITH totals AS (
  SELECT DATE_FORMAT(trans_date, '%Y-%m') AS month, country,
         COUNT(*) AS trans_count, SUM(amount) AS trans_total_amount
  FROM Transactions GROUP BY DATE_FORMAT(trans_date, '%Y-%m'), country
), approved AS (
  SELECT DATE_FORMAT(trans_date, '%Y-%m') AS month, country,
         COUNT(*) AS approved_count, SUM(amount) AS approved_total_amount
  FROM Transactions WHERE state = 'approved' GROUP BY DATE_FORMAT(trans_date, '%Y-%m'), country
)
SELECT t.month, t.country, t.trans_count, COALESCE(a.approved_count, 0) AS approved_count,
       t.trans_total_amount, COALESCE(a.approved_total_amount, 0) AS approved_total_amount
FROM totals t LEFT JOIN approved a ON a.month = t.month AND a.country = t.country;
