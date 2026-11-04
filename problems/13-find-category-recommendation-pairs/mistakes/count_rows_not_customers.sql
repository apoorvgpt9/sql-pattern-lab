-- breaks: edge_typical, edge_fanout_below_threshold
-- MISTAKE: COUNT(*) on the product-level join. A customer who bought two Books products and an Electronics product
-- contributes two rows to (Books, Electronics), so the count measures product combinations, not customers.
SELECT i1.category AS category1, i2.category AS category2, COUNT(*) AS customer_count
FROM ProductPurchases a
JOIN ProductPurchases b ON b.user_id = a.user_id
JOIN ProductInfo i1 ON i1.product_id = a.product_id
JOIN ProductInfo i2 ON i2.product_id = b.product_id
WHERE i1.category < i2.category
GROUP BY i1.category, i2.category
HAVING COUNT(*) >= 3
ORDER BY customer_count DESC, category1 ASC, category2 ASC;
