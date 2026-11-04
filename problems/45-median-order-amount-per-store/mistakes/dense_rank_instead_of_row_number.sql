-- breaks: edge_duplicates
-- MISTAKE: DENSE_RANK compresses ties (1, 1, 1, 2), so position 2 is the 9.00 at the END of the store,
-- not the middle. Wrong value instead of a missing row - harder to notice than RANK's failure.
WITH ranked AS (
  SELECT store_id, amount,
         DENSE_RANK() OVER (PARTITION BY store_id ORDER BY amount) AS rn,
         COUNT(*)     OVER (PARTITION BY store_id)                 AS n
  FROM StoreOrders
)
SELECT store_id, ROUND(AVG(amount), 2) AS median_amount
FROM ranked
WHERE rn IN ((n + 1) DIV 2, n DIV 2 + 1)
GROUP BY store_id
ORDER BY store_id;
