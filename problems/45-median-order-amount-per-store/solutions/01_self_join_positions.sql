-- Approach 1 (brute force, no window functions): each order's position inside its store is
-- 1 + the number of orders in the same store that sort before it on (amount, order_id); n is the
-- store's order count. Keep the one or two middle positions and average them.
WITH positioned AS (
  SELECT o.store_id,
         o.amount,
         1 + (SELECT COUNT(*)
                FROM StoreOrders x
               WHERE x.store_id = o.store_id
                 AND (x.amount < o.amount OR (x.amount = o.amount AND x.order_id < o.order_id))) AS pos,
         (SELECT COUNT(*) FROM StoreOrders x WHERE x.store_id = o.store_id) AS n
  FROM StoreOrders o
)
SELECT store_id, ROUND(AVG(amount), 2) AS median_amount
FROM positioned
WHERE pos IN ((n + 1) DIV 2, n DIV 2 + 1)      -- odd n: the same position twice; even n: the two middle ones
GROUP BY store_id
ORDER BY store_id;
