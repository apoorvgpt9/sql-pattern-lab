-- breaks: edge_typical, edge_no_approved, edge_null_country, edge_month_boundaries
-- MISTAKE: building the label by hand with CONCAT(YEAR, '-', MONTH). January comes out as '2019-1', not '2019-01'.
SELECT CONCAT(YEAR(trans_date), '-', MONTH(trans_date)) AS month, country,
       COUNT(*) AS trans_count, SUM(state = 'approved') AS approved_count,
       SUM(amount) AS trans_total_amount,
       SUM(CASE WHEN state = 'approved' THEN amount ELSE 0 END) AS approved_total_amount
FROM Transactions
GROUP BY CONCAT(YEAR(trans_date), '-', MONTH(trans_date)), country;
