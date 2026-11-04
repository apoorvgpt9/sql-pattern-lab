-- breaks: edge_typical, edge_no_pairs
-- MISTAKE: forgetting that the two products must be bought by the SAME customer. Without b.user_id = a.user_id the
-- self-join pairs every row with every other row, and the count becomes "customers who bought product1", for any product2 that exists.
SELECT a.product_id AS product1_id, b.product_id AS product2_id,
       c1.category AS product1_category, c2.category AS product2_category,
       COUNT(DISTINCT a.user_id) AS customer_count
FROM ProductPurchases a
JOIN ProductPurchases b ON b.product_id > a.product_id
LEFT JOIN ProductInfo c1 ON c1.product_id = a.product_id
LEFT JOIN ProductInfo c2 ON c2.product_id = b.product_id
GROUP BY a.product_id, b.product_id, c1.category, c2.category
HAVING COUNT(DISTINCT a.user_id) >= 3
ORDER BY customer_count DESC, product1_id ASC, product2_id ASC;
