-- breaks: edge_typical, edge_seller_only
-- MISTAKE: joining on either role ("orders the user was part of") counts sales as purchases.
SELECT u.user_id AS buyer_id, u.join_date, COUNT(o.order_id) AS orders_in_2019
FROM Users u
LEFT JOIN Orders o
  ON (o.buyer_id = u.user_id OR o.seller_id = u.user_id)
  AND YEAR(o.order_date) = 2019
GROUP BY u.user_id, u.join_date;
