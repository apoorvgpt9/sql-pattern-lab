-- Approach 3 (optimal): one scan of inventory computes the store size and BOTH rankings; only the
-- (at most two) rank-1 rows per store are kept and folded into one row per store by conditional
-- aggregation. No self-join of inventory. A single product can be rank 1 in both directions (all
-- prices equal); the conditional aggregation then fills both columns from that one row.
WITH ranked AS (
  SELECT store_id, product_name, quantity,
         COUNT(*)     OVER (PARTITION BY store_id)                                           AS n_products,
         ROW_NUMBER() OVER (PARTITION BY store_id ORDER BY price DESC, quantity DESC, product_name ASC) AS rn_hi,
         ROW_NUMBER() OVER (PARTITION BY store_id ORDER BY price ASC,  quantity DESC, product_name ASC) AS rn_lo
  FROM inventory
), ends AS (
  SELECT store_id,
         MAX(CASE WHEN rn_hi = 1 THEN product_name END) AS most_exp_product,
         MAX(CASE WHEN rn_hi = 1 THEN quantity     END) AS hi_qty,
         MAX(CASE WHEN rn_lo = 1 THEN product_name END) AS cheapest_product,
         MAX(CASE WHEN rn_lo = 1 THEN quantity     END) AS lo_qty
  FROM ranked
  WHERE n_products >= 3
    AND (rn_hi = 1 OR rn_lo = 1)
  GROUP BY store_id
)
SELECT
  s.store_id,
  s.store_name,
  s.location,
  e.most_exp_product,
  e.cheapest_product,
  ROUND(e.lo_qty / e.hi_qty, 2) AS imbalance_ratio
FROM ends e
JOIN stores s ON s.store_id = e.store_id
WHERE e.hi_qty < e.lo_qty
ORDER BY imbalance_ratio DESC, s.store_name ASC;
