-- breaks: edge_null_country
-- MISTAKE: COUNT(country) instead of COUNT(*). COUNT(col) skips NULLs, so the NULL-country group reports 0 transactions.
SELECT DATE_FORMAT(trans_date, '%Y-%m') AS month, country,
       COUNT(country) AS trans_count, SUM(state = 'approved') AS approved_count,
       SUM(amount) AS trans_total_amount,
       SUM(CASE WHEN state = 'approved' THEN amount ELSE 0 END) AS approved_total_amount
FROM Transactions
GROUP BY DATE_FORMAT(trans_date, '%Y-%m'), country;
