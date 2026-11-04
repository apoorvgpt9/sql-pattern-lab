-- breaks: edge_ordering
-- MISTAKE: tie-break on product2_id before product1_id. Among the equal-count pairs this puts (7,9) before (5,12).
SELECT a.product_id AS product1_id, b.product_id AS product2_id,
       c1.category AS product1_category, c2.category AS product2_category,
       COUNT(DISTINCT a.user_id) AS customer_count
FROM ProductPurchases a
JOIN ProductPurchases b ON b.user_id = a.user_id AND b.product_id > a.product_id
LEFT JOIN ProductInfo c1 ON c1.product_id = a.product_id
LEFT JOIN ProductInfo c2 ON c2.product_id = b.product_id
GROUP BY a.product_id, b.product_id, c1.category, c2.category
HAVING COUNT(DISTINCT a.user_id) >= 3
ORDER BY customer_count DESC, product2_id ASC, product1_id ASC;
