-- breaks: edge_typical, edge_no_approved, edge_null_country
-- MISTAKE: "approved" put in WHERE. Every number is then computed over approved rows only: trans_count equals
-- approved_count, and groups with no approved row disappear.
SELECT DATE_FORMAT(trans_date, '%Y-%m') AS month, country,
       COUNT(*) AS trans_count, COUNT(*) AS approved_count,
       SUM(amount) AS trans_total_amount, SUM(amount) AS approved_total_amount
FROM Transactions
WHERE state = 'approved'
GROUP BY DATE_FORMAT(trans_date, '%Y-%m'), country;
