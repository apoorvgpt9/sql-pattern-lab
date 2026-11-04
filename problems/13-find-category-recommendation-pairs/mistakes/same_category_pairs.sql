-- breaks: edge_typical, edge_single_category
-- MISTAKE: category1 <= category2. A category is paired with itself, so (Books, Books) is reported for every
-- customer who bought anything in Books.
WITH cust_cat AS (
  SELECT DISTINCT pp.user_id, pi.category
  FROM ProductPurchases pp JOIN ProductInfo pi ON pi.product_id = pp.product_id
  WHERE pi.category IS NOT NULL
)
SELECT a.category AS category1, b.category AS category2, COUNT(*) AS customer_count
FROM cust_cat a JOIN cust_cat b ON b.user_id = a.user_id AND b.category >= a.category
GROUP BY a.category, b.category
HAVING COUNT(*) >= 3
ORDER BY customer_count DESC, category1 ASC, category2 ASC;
