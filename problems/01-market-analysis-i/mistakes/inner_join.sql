-- breaks: edge_typical, edge_no_orders, edge_year_boundaries, edge_seller_only, edge_nulls
-- MISTAKE: an INNER JOIN keeps only users who have a matching 2019 buyer order; the zeros vanish.
SELECT u.user_id AS buyer_id, u.join_date, COUNT(*) AS orders_in_2019
FROM Users u
JOIN Orders o ON o.buyer_id = u.user_id AND YEAR(o.order_date) = 2019
GROUP BY u.user_id, u.join_date;
