-- Approach 3 (optimal, measured): number each store's orders twice, ascending and descending. The middle row(s) are
-- where the two numbers meet: |rn_asc - rn_desc| <= 1. No count needed, but two different sorts.
-- The descending order must be the exact reverse of the ascending one, tie-break included.
WITH numbered AS (
  SELECT store_id,
         amount,
         ROW_NUMBER() OVER (PARTITION BY store_id ORDER BY amount ASC,  order_id ASC)  AS rn_asc,
         ROW_NUMBER() OVER (PARTITION BY store_id ORDER BY amount DESC, order_id DESC) AS rn_desc
  FROM StoreOrders
)
SELECT store_id, ROUND(AVG(amount), 2) AS median_amount
FROM numbered
WHERE rn_asc BETWEEN rn_desc - 1 AND rn_desc + 1
GROUP BY store_id
ORDER BY store_id;
