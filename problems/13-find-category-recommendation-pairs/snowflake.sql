-- UNVERIFIED: Snowflake version of the optimal approach (03). CI cannot run Snowflake.
-- Same shape as MySQL; differences are noted in README section 9 (notably: string comparison is case-sensitive there).
WITH cust_cat AS (
  SELECT DISTINCT pp.user_id, pi.category
  FROM ProductPurchases pp
  JOIN ProductInfo pi ON pi.product_id = pp.product_id
  WHERE pi.category IS NOT NULL
)
SELECT a.category AS category1, b.category AS category2, COUNT(*) AS customer_count
FROM cust_cat a
JOIN cust_cat b ON b.user_id = a.user_id AND b.category > a.category
GROUP BY a.category, b.category
HAVING COUNT(*) >= 3
ORDER BY customer_count DESC, category1, category2;
