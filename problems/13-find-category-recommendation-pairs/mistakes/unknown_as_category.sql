-- breaks: edge_unmapped_and_null
-- MISTAKE: "be safe" with COALESCE(category, 'Unknown') and a LEFT JOIN. Purchases that have no category are not a category;
-- this invents an 'Unknown' one and pairs it with real categories.
WITH cust_cat AS (
  SELECT DISTINCT pp.user_id, COALESCE(pi.category, 'Unknown') AS category
  FROM ProductPurchases pp LEFT JOIN ProductInfo pi ON pi.product_id = pp.product_id
)
SELECT a.category AS category1, b.category AS category2, COUNT(*) AS customer_count
FROM cust_cat a JOIN cust_cat b ON b.user_id = a.user_id AND b.category > a.category
GROUP BY a.category, b.category
HAVING COUNT(*) >= 3
ORDER BY customer_count DESC, category1 ASC, category2 ASC;
