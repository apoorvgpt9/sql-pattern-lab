-- breaks: edge_month_boundaries
-- MISTAKE: grouping by MONTH() (1-12) instead of year and month. January 2019 and January 2020 merge into one group
-- (labelled with whichever year happens to be earliest).
SELECT DATE_FORMAT(MIN(trans_date), '%Y-%m') AS month, country,
       COUNT(*) AS trans_count, SUM(state = 'approved') AS approved_count,
       SUM(amount) AS trans_total_amount,
       SUM(CASE WHEN state = 'approved' THEN amount ELSE 0 END) AS approved_total_amount
FROM Transactions
GROUP BY MONTH(trans_date), country;
