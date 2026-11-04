-- breaks: edge_typical, edge_empty_users
-- MISTAKE: starting from Orders makes the output grain "buyers who ordered in 2019", not "users".
-- Users with 0 are missing and buyers who are not users appear (join_date NULL).
SELECT o.buyer_id, u.join_date, COUNT(*) AS orders_in_2019
FROM Orders o
LEFT JOIN Users u ON u.user_id = o.buyer_id
WHERE YEAR(o.order_date) = 2019
GROUP BY o.buyer_id, u.join_date;
