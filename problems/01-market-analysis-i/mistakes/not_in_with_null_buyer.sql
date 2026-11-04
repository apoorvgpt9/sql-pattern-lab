-- breaks: edge_nulls
-- MISTAKE: split into "users who bought" UNION "users who did not". NOT IN against a list that
-- contains a NULL is never true (x <> NULL is unknown), so the zero-order users vanish as soon as
-- one 2019 order has buyer_id NULL. Passes every dataset without a NULL buyer - which is the trap.
SELECT u.user_id AS buyer_id, u.join_date, COUNT(*) AS orders_in_2019
FROM Users u
JOIN Orders o ON o.buyer_id = u.user_id AND YEAR(o.order_date) = 2019
GROUP BY u.user_id, u.join_date
UNION ALL
SELECT u.user_id, u.join_date, 0
FROM Users u
WHERE u.user_id NOT IN (SELECT buyer_id FROM Orders WHERE YEAR(order_date) = 2019);
