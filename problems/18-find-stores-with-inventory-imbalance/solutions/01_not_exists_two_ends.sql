-- Approach 1 (brute force): find the most expensive and the cheapest row of each store with two
-- "nobody beats me" anti-joins, then join the two rows by store. The store-size filter is a
-- correlated count. Tie-break at both ends: higher quantity, then smaller product_name.
SELECT
  s.store_id,
  s.store_name,
  s.location,
  hi.product_name                                   AS most_exp_product,
  lo.product_name                                   AS cheapest_product,
  ROUND(lo.quantity / hi.quantity, 2)               AS imbalance_ratio
FROM stores s
JOIN inventory hi
  ON hi.store_id = s.store_id
 AND NOT EXISTS (SELECT 1 FROM inventory x
                  WHERE x.store_id = hi.store_id
                    AND ( x.price > hi.price
                       OR (x.price = hi.price AND x.quantity > hi.quantity)
                       OR (x.price = hi.price AND x.quantity = hi.quantity
                           AND x.product_name < hi.product_name) ))
JOIN inventory lo
  ON lo.store_id = s.store_id
 AND NOT EXISTS (SELECT 1 FROM inventory y
                  WHERE y.store_id = lo.store_id
                    AND ( y.price < lo.price
                       OR (y.price = lo.price AND y.quantity > lo.quantity)
                       OR (y.price = lo.price AND y.quantity = lo.quantity
                           AND y.product_name < lo.product_name) ))
WHERE (SELECT COUNT(*) FROM inventory c WHERE c.store_id = s.store_id) >= 3
  AND hi.quantity < lo.quantity
ORDER BY imbalance_ratio DESC, s.store_name ASC;
