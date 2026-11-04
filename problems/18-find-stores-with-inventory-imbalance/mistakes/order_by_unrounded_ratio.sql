-- breaks: edge_ordering
-- MISTAKE: orders by the unrounded quotient. The spec orders by the output column imbalance_ratio, which is rounded, so stores that round to the same value must be ordered by store_name. Beta2 (1.6700) wrongly precedes Alpha2 (1.6667).
WITH r AS (
  SELECT store_id, product_name, quantity,
         COUNT(*) OVER (PARTITION BY store_id) AS n_products,
         ROW_NUMBER() OVER (PARTITION BY store_id ORDER BY price DESC, quantity DESC, product_name ASC) AS rn_hi,
         ROW_NUMBER() OVER (PARTITION BY store_id ORDER BY price ASC,  quantity DESC, product_name ASC) AS rn_lo
  FROM inventory
), e AS (
  SELECT store_id,
         MAX(CASE WHEN rn_hi = 1 THEN product_name END) AS most_exp_product,
         MAX(CASE WHEN rn_hi = 1 THEN quantity END) AS hi_qty,
         MAX(CASE WHEN rn_lo = 1 THEN product_name END) AS cheapest_product,
         MAX(CASE WHEN rn_lo = 1 THEN quantity END) AS lo_qty
  FROM r WHERE n_products >= 3 AND (rn_hi = 1 OR rn_lo = 1) GROUP BY store_id
)
SELECT s.store_id, s.store_name, s.location, e.most_exp_product, e.cheapest_product,
       ROUND(e.lo_qty / e.hi_qty, 2) AS imbalance_ratio
FROM e JOIN stores s ON s.store_id = e.store_id
WHERE e.hi_qty < e.lo_qty
ORDER BY e.lo_qty / e.hi_qty DESC, s.store_name;
