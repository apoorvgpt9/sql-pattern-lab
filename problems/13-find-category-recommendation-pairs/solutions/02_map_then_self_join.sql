-- Approach 2: translate products to categories BEFORE the self-join (one lookup per purchase instead of two per joined row),
-- then self-join and COUNT(DISTINCT customer). The fan-out from several products per category still exists in the join;
-- only the dimension lookups got cheaper.
WITH cust_cat AS (
  SELECT pp.user_id, pi.category
  FROM ProductPurchases pp
  JOIN ProductInfo pi ON pi.product_id = pp.product_id
  WHERE pi.category IS NOT NULL
)
SELECT
  a.category AS category1,
  b.category AS category2,
  COUNT(DISTINCT a.user_id) AS customer_count
FROM cust_cat a
JOIN cust_cat b
  ON  b.user_id  = a.user_id
  AND b.category > a.category
GROUP BY a.category, b.category
HAVING COUNT(DISTINCT a.user_id) >= 3
ORDER BY customer_count DESC, category1 ASC, category2 ASC;
