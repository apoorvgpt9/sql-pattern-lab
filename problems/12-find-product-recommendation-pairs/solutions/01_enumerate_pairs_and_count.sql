-- Approach 1 (brute force): write down every pair of purchased products (p1 < p2), then for each pair
-- count the customers who bought both with a correlated subquery. Reads exactly like the spec.
-- Cost is (number of products)^2 pairs, each probing the purchases table: it does not need the pair to exist in the data.
-- Categories are attached by LEFT JOIN so a product without a ProductInfo row does not drop a qualifying pair.
SELECT
  q.product1_id,
  q.product2_id,
  c1.category AS product1_category,
  c2.category AS product2_category,
  q.customer_count
FROM (
  SELECT
    pr.p1 AS product1_id,
    pr.p2 AS product2_id,
    (SELECT COUNT(DISTINCT x.user_id)
       FROM ProductPurchases x
       JOIN ProductPurchases y ON y.user_id = x.user_id
      WHERE x.product_id = pr.p1 AND y.product_id = pr.p2) AS customer_count
  FROM (
    SELECT a.product_id AS p1, b.product_id AS p2
    FROM (SELECT DISTINCT product_id FROM ProductPurchases) a
    JOIN (SELECT DISTINCT product_id FROM ProductPurchases) b ON a.product_id < b.product_id
  ) pr
) q
LEFT JOIN ProductInfo c1 ON c1.product_id = q.product1_id
LEFT JOIN ProductInfo c2 ON c2.product_id = q.product2_id
WHERE q.customer_count >= 3
ORDER BY q.customer_count DESC, q.product1_id ASC, q.product2_id ASC;
