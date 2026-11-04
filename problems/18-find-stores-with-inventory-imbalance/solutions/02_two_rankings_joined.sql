-- Approach 2: rank each store's products twice, once per direction, in two separate CTEs, and join
-- the two rank-1 rows by store. The store size comes from COUNT(*) OVER (PARTITION BY store_id).
-- Two scans of inventory and one self-join, but no per-row subqueries.
WITH top_priced AS (
  SELECT store_id, product_name, quantity,
         COUNT(*)     OVER (PARTITION BY store_id)                                           AS n_products,
         ROW_NUMBER() OVER (PARTITION BY store_id ORDER BY price DESC, quantity DESC, product_name ASC) AS rn
  FROM inventory
), low_priced AS (
  SELECT store_id, product_name, quantity,
         ROW_NUMBER() OVER (PARTITION BY store_id ORDER BY price ASC, quantity DESC, product_name ASC) AS rn
  FROM inventory
)
SELECT
  s.store_id,
  s.store_name,
  s.location,
  hi.product_name                         AS most_exp_product,
  lo.product_name                         AS cheapest_product,
  ROUND(lo.quantity / hi.quantity, 2)     AS imbalance_ratio
FROM stores s
JOIN top_priced hi ON hi.store_id = s.store_id AND hi.rn = 1
JOIN low_priced lo ON lo.store_id = s.store_id AND lo.rn = 1
WHERE hi.n_products >= 3
  AND hi.quantity < lo.quantity
ORDER BY imbalance_ratio DESC, s.store_name ASC;
