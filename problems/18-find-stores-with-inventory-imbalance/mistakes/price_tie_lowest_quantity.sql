-- breaks: edge_price_ties
-- MISTAKE: breaks price ties by the SMALLER quantity (ORDER BY price, quantity ASC) at both ends.
-- The reference rule prefers the larger quantity, so Tie1 wrongly qualifies (A has 2 units, not B's 5)
-- and Tie2 picks Y (3 units) instead of Z (9 units).
WITH r AS (
  SELECT store_id, product_name, quantity,
         COUNT(*) OVER (PARTITION BY store_id) AS n_products,
         ROW_NUMBER() OVER (PARTITION BY store_id ORDER BY price DESC, quantity ASC, product_name ASC) AS rn_hi,
         ROW_NUMBER() OVER (PARTITION BY store_id ORDER BY price ASC,  quantity ASC, product_name ASC) AS rn_lo
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
ORDER BY imbalance_ratio DESC, s.store_name;
