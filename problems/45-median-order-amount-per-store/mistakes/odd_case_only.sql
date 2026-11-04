-- breaks: edge_typical, edge_rounding, edge_order
-- MISTAKE: only the "middle element" position (n+1) DIV 2. Right for odd n; for even n it returns
-- the lower middle value instead of the mean of the two middle values.
WITH ranked AS (
  SELECT store_id, amount,
         ROW_NUMBER() OVER (PARTITION BY store_id ORDER BY amount, order_id) AS rn,
         COUNT(*)     OVER (PARTITION BY store_id)                          AS n
  FROM StoreOrders
)
SELECT store_id, ROUND(AVG(amount), 2) AS median_amount
FROM ranked
WHERE rn = (n + 1) DIV 2
GROUP BY store_id
ORDER BY store_id;
