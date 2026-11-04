-- breaks: edge_typical, edge_no_orders, edge_year_boundaries, edge_seller_only, edge_nulls
-- MISTAKE: COUNT(*) counts the one all-NULL row that the LEFT JOIN produces for an unmatched
-- user, so every user with no 2019 orders gets 1 instead of 0.
SELECT u.user_id AS buyer_id, u.join_date, COUNT(*) AS orders_in_2019
FROM Users u
LEFT JOIN Orders o
  ON o.buyer_id = u.user_id AND YEAR(o.order_date) = 2019
GROUP BY u.user_id, u.join_date;
