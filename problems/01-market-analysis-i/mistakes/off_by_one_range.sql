-- breaks: edge_year_boundaries
-- MISTAKE: strict comparisons on both ends drop 2019-01-01 and 2019-12-31.
-- Half-open is the habit to build: >= first day AND < first day of the next period.
SELECT u.user_id AS buyer_id, u.join_date, COUNT(o.order_id) AS orders_in_2019
FROM Users u
LEFT JOIN Orders o
  ON o.buyer_id = u.user_id
  AND o.order_date > '2019-01-01' AND o.order_date < '2019-12-31'
GROUP BY u.user_id, u.join_date;
