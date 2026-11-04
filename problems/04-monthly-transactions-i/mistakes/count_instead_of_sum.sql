-- breaks: edge_typical, edge_no_approved, edge_null_country, edge_month_boundaries
-- MISTAKE: COUNT(state = 'approved') to count approved rows. COUNT counts non-NULL values, and the comparison is
-- 0 or 1, never NULL, so it counts every row and equals trans_count. SUM (or COUNT(CASE ... END)) is what counts matches.
SELECT DATE_FORMAT(trans_date, '%Y-%m') AS month, country,
       COUNT(*) AS trans_count, COUNT(state = 'approved') AS approved_count,
       SUM(amount) AS trans_total_amount,
       SUM(CASE WHEN state = 'approved' THEN amount ELSE 0 END) AS approved_total_amount
FROM Transactions
GROUP BY DATE_FORMAT(trans_date, '%Y-%m'), country;
