-- Approach 3 (optimal): shrink the self-join's input first. A pair needs >= 3 customers, so each of its two
-- products must individually have >= 3 customers. Products below that can never appear in an output pair, so
-- their rows are removed BEFORE the join, which is where the row explosion (k*(k-1)/2 pairs per basket) happens.
-- (user_id, product_id) is the primary key, so each row is one customer and COUNT(*) equals the distinct customers.
WITH popular AS (
  SELECT product_id
  FROM ProductPurchases
  GROUP BY product_id
  HAVING COUNT(*) >= 3
),
basket AS (
  SELECT pp.user_id, pp.product_id
  FROM ProductPurchases pp
  JOIN popular p ON p.product_id = pp.product_id
),
pairs AS (
  SELECT a.product_id AS product1_id, b.product_id AS product2_id, COUNT(*) AS customer_count
  FROM basket a
  JOIN basket b
    ON  b.user_id    = a.user_id
    AND b.product_id > a.product_id
  GROUP BY a.product_id, b.product_id
  HAVING COUNT(*) >= 3
)
SELECT
  p.product1_id,
  p.product2_id,
  c1.category AS product1_category,
  c2.category AS product2_category,
  p.customer_count
FROM pairs p
LEFT JOIN ProductInfo c1 ON c1.product_id = p.product1_id
LEFT JOIN ProductInfo c2 ON c2.product_id = p.product2_id
ORDER BY p.customer_count DESC, p.product1_id ASC, p.product2_id ASC;
