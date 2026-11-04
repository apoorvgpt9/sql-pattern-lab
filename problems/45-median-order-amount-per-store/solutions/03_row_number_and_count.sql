-- Approach 3 (optimal): one sort per store. ROW_NUMBER gives each order's position; COUNT over the
-- SAME window ordering, with a frame covering the whole partition, gives n in the same pass.
-- (Written as COUNT(*) OVER (PARTITION BY store_id) instead, MySQL evaluates it as a second window
-- with its own sort - checked with EXPLAIN.) The middle positions are (n+1) DIV 2 and n DIV 2 + 1
-- (equal when n is odd), so AVG over the kept rows is the median in both cases.
WITH ranked AS (
  SELECT store_id,
         amount,
         ROW_NUMBER() OVER w AS rn,
         COUNT(*)     OVER (w ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS n
  FROM StoreOrders
  WINDOW w AS (PARTITION BY store_id ORDER BY amount, order_id)
)
SELECT store_id, ROUND(AVG(amount), 2) AS median_amount
FROM ranked
WHERE rn IN ((n + 1) DIV 2, n DIV 2 + 1)
GROUP BY store_id
ORDER BY store_id;
