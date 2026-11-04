-- breaks: edge_typical, edge_no_approved
-- MISTAKE: CASE WHEN approved THEN amount END with no ELSE. A group with no approved row sums only NULLs,
-- and SUM of only NULLs is NULL, not 0. The spec wants 0.
SELECT DATE_FORMAT(trans_date, '%Y-%m') AS month, country,
       COUNT(*) AS trans_count, SUM(state = 'approved') AS approved_count,
       SUM(amount) AS trans_total_amount,
       SUM(CASE WHEN state = 'approved' THEN amount END) AS approved_total_amount
FROM Transactions
GROUP BY DATE_FORMAT(trans_date, '%Y-%m'), country;
