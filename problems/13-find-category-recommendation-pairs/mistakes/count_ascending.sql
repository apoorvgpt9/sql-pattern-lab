-- breaks: edge_ordering
-- MISTAKE: customer_count ascending; the spec wants the most popular pair first.
WITH cust_cat AS (
  SELECT DISTINCT pp.user_id, pi.category
  FROM ProductPurchases pp JOIN ProductInfo pi ON pi.product_id = pp.product_id
  WHERE pi.category IS NOT NULL
)
SELECT a.category AS category1, b.category AS category2, COUNT(*) AS customer_count
FROM cust_cat a JOIN cust_cat b ON b.user_id = a.user_id AND b.category > a.category
GROUP BY a.category, b.category
HAVING COUNT(*) >= 3
ORDER BY customer_count ASC, category1 ASC, category2 ASC;
