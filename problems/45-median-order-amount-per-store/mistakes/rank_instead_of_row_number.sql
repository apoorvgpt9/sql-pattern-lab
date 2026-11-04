-- breaks: edge_duplicates
-- MISTAKE: RANK gives tied amounts the same position and then skips (1, 1, 1, 4). The middle
-- positions 2 and 3 then do not exist, and the store silently disappears from the result.
WITH ranked AS (
  SELECT store_id, amount,
         RANK()   OVER (PARTITION BY store_id ORDER BY amount) AS rn,
         COUNT(*) OVER (PARTITION BY store_id)                 AS n
  FROM StoreOrders
)
SELECT store_id, ROUND(AVG(amount), 2) AS median_amount
FROM ranked
WHERE rn IN ((n + 1) DIV 2, n DIV 2 + 1)
GROUP BY store_id
ORDER BY store_id;
