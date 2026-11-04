-- UNVERIFIED: Snowflake version of the optimal approach (03). CI cannot run Snowflake.
-- QUALIFY cannot express two different rankings on the same row set in one filter, so the shape of
-- the MySQL version is kept; MAX_BY(x, y) could replace the CASE-inside-MAX folding (see README section 9).
WITH ranked AS (
  SELECT store_id, product_name, quantity,
         COUNT(*)     OVER (PARTITION BY store_id)                                           AS n_products,
         ROW_NUMBER() OVER (PARTITION BY store_id ORDER BY price DESC, quantity DESC, product_name ASC) AS rn_hi,
         ROW_NUMBER() OVER (PARTITION BY store_id ORDER BY price ASC,  quantity DESC, product_name ASC) AS rn_lo
  FROM inventory
), ends AS (
  SELECT store_id,
         MAX(IFF(rn_hi = 1, product_name, NULL)) AS most_exp_product,
         MAX(IFF(rn_hi = 1, quantity,     NULL)) AS hi_qty,
         MAX(IFF(rn_lo = 1, product_name, NULL)) AS cheapest_product,
         MAX(IFF(rn_lo = 1, quantity,     NULL)) AS lo_qty
  FROM ranked
  WHERE n_products >= 3
    AND (rn_hi = 1 OR rn_lo = 1)
  GROUP BY store_id
)
SELECT s.store_id, s.store_name, s.location, e.most_exp_product, e.cheapest_product,
       ROUND(e.lo_qty / e.hi_qty, 2) AS imbalance_ratio
FROM ends e
JOIN stores s ON s.store_id = e.store_id
WHERE e.hi_qty < e.lo_qty
ORDER BY imbalance_ratio DESC, s.store_name ASC;
