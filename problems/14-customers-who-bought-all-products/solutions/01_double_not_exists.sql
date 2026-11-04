-- Approach 1 (brute force): division written straight from its definition. A customer qualifies when there is NO
-- product for which there is NO purchase by that customer. For each customer, probe each product.
-- Robust to duplicates and NULL product_keys by construction (the inner EXISTS only asks "is there a row?").
SELECT c.customer_id
FROM (SELECT DISTINCT customer_id FROM Customer) c
WHERE NOT EXISTS (
  SELECT 1
  FROM Product p
  WHERE NOT EXISTS (
    SELECT 1
    FROM Customer x
    WHERE x.customer_id = c.customer_id
      AND x.product_key = p.product_key
  )
);
