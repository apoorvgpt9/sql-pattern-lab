-- Approach 1 (brute force): self-join the purchases at PRODUCT grain, look up both categories on every joined
-- row, keep category1 < category2, and count DISTINCT customers per category pair.
-- Correct: COUNT(DISTINCT user_id) undoes the fan-out (a customer with several products per category appears in many
-- joined rows). The cost is that fan-out: sum over customers of (products per customer)^2 rows, each with two dimension lookups.
SELECT
  i1.category AS category1,
  i2.category AS category2,
  COUNT(DISTINCT a.user_id) AS customer_count
FROM ProductPurchases a
JOIN ProductPurchases b ON b.user_id = a.user_id
JOIN ProductInfo i1 ON i1.product_id = a.product_id
JOIN ProductInfo i2 ON i2.product_id = b.product_id
WHERE i1.category < i2.category
GROUP BY i1.category, i2.category
HAVING COUNT(DISTINCT a.user_id) >= 3
ORDER BY customer_count DESC, category1 ASC, category2 ASC;
