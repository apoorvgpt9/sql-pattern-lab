-- breaks: edge_typical, edge_order
-- MISTAKE: switching to integer division but keeping the even-case formula for every n:
-- positions n DIV 2 and n DIV 2 + 1. For n = 5 that averages positions 2 and 3 instead of taking 3;
-- for n = 1 it keeps only position 1 (0 does not exist), which happens to be right.
WITH ranked AS (
  SELECT store_id, amount,
         ROW_NUMBER() OVER (PARTITION BY store_id ORDER BY amount, order_id) AS rn,
         COUNT(*)     OVER (PARTITION BY store_id)                          AS n
  FROM StoreOrders
)
SELECT store_id, ROUND(AVG(amount), 2) AS median_amount
FROM ranked
WHERE rn IN (n DIV 2, n DIV 2 + 1)
GROUP BY store_id
ORDER BY store_id;
