-- Approach 3 (optimal) (brute force): for each distinct product, look up its most recent change on or before the
-- date with a correlated ORDER BY ... LIMIT 1 subquery. No matching row gives NULL, which COALESCE turns
-- into the initial price 10.
SELECT
  p.product_id,
  COALESCE((SELECT x.new_price
              FROM Products x
             WHERE x.product_id  = p.product_id
               AND x.change_date <= '2019-08-16'
             ORDER BY x.change_date DESC
             LIMIT 1), 10) AS price
FROM (SELECT DISTINCT product_id FROM Products) p;
