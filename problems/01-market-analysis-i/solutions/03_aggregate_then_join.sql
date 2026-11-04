-- Approach 3 (optimal): shrink Orders to one row per 2019 buyer, then attach it to every user.
-- The filter sits inside the CTE, so it can never touch the Users side of the LEFT JOIN.
WITH buyer_2019 AS (
  SELECT buyer_id, COUNT(*) AS n_orders
  FROM Orders
  WHERE order_date >= '2019-01-01'
    AND order_date <  '2020-01-01'
  GROUP BY buyer_id
)
SELECT
  u.user_id                 AS buyer_id,
  u.join_date,
  COALESCE(b.n_orders, 0)   AS orders_in_2019
FROM Users u
LEFT JOIN buyer_2019 b
  ON b.buyer_id = u.user_id;
