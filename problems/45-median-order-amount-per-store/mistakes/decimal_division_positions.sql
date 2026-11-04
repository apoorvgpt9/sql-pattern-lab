-- breaks: edge_typical, edge_duplicates, edge_order
-- MISTAKE: middle positions written as n / 2 and n / 2 + 1. In MySQL "/" is decimal division, so for
-- odd n they are 2.5000 and 3.5000; no integer row number equals them and every odd-sized store
-- (including one-order stores) vanishes. Use DIV or FLOOR.
WITH ranked AS (
  SELECT store_id, amount,
         ROW_NUMBER() OVER (PARTITION BY store_id ORDER BY amount, order_id) AS rn,
         COUNT(*)     OVER (PARTITION BY store_id)                          AS n
  FROM StoreOrders
)
SELECT store_id, ROUND(AVG(amount), 2) AS median_amount
FROM ranked
WHERE rn IN (n / 2, n / 2 + 1)
GROUP BY store_id
ORDER BY store_id;
