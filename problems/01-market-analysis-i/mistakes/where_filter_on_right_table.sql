-- breaks: edge_typical, edge_no_orders, edge_year_boundaries, edge_seller_only, edge_nulls
-- MISTAKE: the 2019 filter is in WHERE. For a user with no 2019 buyer orders the joined Orders
-- columns are NULL, YEAR(NULL) = 2019 is not true, and WHERE deletes the user: the LEFT JOIN
-- has silently become an INNER JOIN.
SELECT u.user_id AS buyer_id, u.join_date, COUNT(o.order_id) AS orders_in_2019
FROM Users u
LEFT JOIN Orders o ON o.buyer_id = u.user_id
WHERE YEAR(o.order_date) = 2019
GROUP BY u.user_id, u.join_date;
