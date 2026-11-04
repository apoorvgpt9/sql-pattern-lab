-- Approach 2: join first, then group. The 2019 filter lives in ON so it cannot remove users,
-- and COUNT(o.order_id) counts only matched orders (an unmatched user has one all-NULL Orders row).
SELECT
  u.user_id         AS buyer_id,
  u.join_date,
  COUNT(o.order_id) AS orders_in_2019
FROM Users u
LEFT JOIN Orders o
  ON  o.buyer_id   = u.user_id
  AND o.order_date >= '2019-01-01'
  AND o.order_date <  '2020-01-01'
GROUP BY u.user_id, u.join_date;
