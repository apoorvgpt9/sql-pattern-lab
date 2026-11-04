-- breaks: edge_typical, edge_threshold
-- MISTAKE: HAVING count > 3. "At least 3" includes 3.
WITH cust_cat AS (
  SELECT DISTINCT pp.user_id, pi.category
  FROM ProductPurchases pp JOIN ProductInfo pi ON pi.product_id = pp.product_id
  WHERE pi.category IS NOT NULL
)
SELECT a.category AS category1, b.category AS category2, COUNT(*) AS customer_count
FROM cust_cat a JOIN cust_cat b ON b.user_id = a.user_id AND b.category > a.category
GROUP BY a.category, b.category
HAVING COUNT(*) > 3
ORDER BY customer_count DESC, category1 ASC, category2 ASC;
