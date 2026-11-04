-- breaks: edge_typical
-- MISTAKE: only counting purchases with quantity > 0 "to be safe". The spec says quantity is irrelevant: a row
-- in ProductPurchases means the customer bought the product.
SELECT a.product_id AS product1_id, b.product_id AS product2_id,
       c1.category AS product1_category, c2.category AS product2_category,
       COUNT(DISTINCT a.user_id) AS customer_count
FROM ProductPurchases a
JOIN ProductPurchases b ON b.user_id = a.user_id AND b.product_id > a.product_id
LEFT JOIN ProductInfo c1 ON c1.product_id = a.product_id
LEFT JOIN ProductInfo c2 ON c2.product_id = b.product_id
WHERE a.quantity > 0 AND b.quantity > 0
GROUP BY a.product_id, b.product_id, c1.category, c2.category
HAVING COUNT(DISTINCT a.user_id) >= 3
ORDER BY customer_count DESC, product1_id ASC, product2_id ASC;
