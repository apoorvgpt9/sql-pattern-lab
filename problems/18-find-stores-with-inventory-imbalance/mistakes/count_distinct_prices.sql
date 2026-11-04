-- breaks: edge_price_ties, edge_full_tie_assumption
-- MISTAKE: reads "at least 3 different products" as 3 different PRICES (COUNT(DISTINCT price)).
-- The spec counts products (inventory rows). Tie2 has three products but only two distinct prices,
-- so it is wrongly dropped.
WITH r AS (
  SELECT store_id, product_name, quantity,
         ROW_NUMBER() OVER (PARTITION BY store_id ORDER BY price DESC, quantity DESC, product_name ASC) AS rn_hi,
         ROW_NUMBER() OVER (PARTITION BY store_id ORDER BY price ASC,  quantity DESC, product_name ASC) AS rn_lo
  FROM inventory
  WHERE store_id IN (SELECT store_id FROM inventory GROUP BY store_id HAVING COUNT(DISTINCT price) >= 3)
), e AS (
  SELECT store_id,
         MAX(CASE WHEN rn_hi = 1 THEN product_name END) AS most_exp_product,
         MAX(CASE WHEN rn_hi = 1 THEN quantity END) AS hi_qty,
         MAX(CASE WHEN rn_lo = 1 THEN product_name END) AS cheapest_product,
         MAX(CASE WHEN rn_lo = 1 THEN quantity END) AS lo_qty
  FROM r WHERE rn_hi = 1 OR rn_lo = 1 GROUP BY store_id
)
SELECT s.store_id, s.store_name, s.location, e.most_exp_product, e.cheapest_product,
       ROUND(e.lo_qty / e.hi_qty, 2) AS imbalance_ratio
FROM e JOIN stores s ON s.store_id = e.store_id
WHERE e.hi_qty < e.lo_qty
ORDER BY imbalance_ratio DESC, s.store_name;
