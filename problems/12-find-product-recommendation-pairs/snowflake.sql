-- UNVERIFIED: Snowflake version of the optimal approach (03). CI cannot run Snowflake.
-- Same shape as MySQL; differences are noted in README section 9. (The popularity prune of approach 02 is not applied here:
-- whether it helps on Snowflake is untested.)
WITH pairs AS (
  SELECT a.product_id AS product1_id, b.product_id AS product2_id, COUNT(DISTINCT a.user_id) AS customer_count
  FROM ProductPurchases a
  JOIN ProductPurchases b
    ON b.user_id = a.user_id AND b.product_id > a.product_id
  GROUP BY a.product_id, b.product_id
  HAVING COUNT(DISTINCT a.user_id) >= 3
)
SELECT p.product1_id, p.product2_id, c1.category AS product1_category, c2.category AS product2_category, p.customer_count
FROM pairs p
LEFT JOIN ProductInfo c1 ON c1.product_id = p.product1_id
LEFT JOIN ProductInfo c2 ON c2.product_id = p.product2_id
ORDER BY p.customer_count DESC, p.product1_id, p.product2_id;
