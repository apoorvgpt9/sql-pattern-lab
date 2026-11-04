-- breaks: edge_null_product_key
-- MISTAKE: "customers with no product outside their purchases", written with NOT IN against a column that contains NULL.
-- p.product_key NOT IN (list containing NULL) is never true, so NO product counts as missing for ANY customer who has a
-- NULL row, and that customer qualifies although they lack products.
SELECT c.customer_id
FROM (SELECT DISTINCT customer_id FROM Customer) c
WHERE NOT EXISTS (
  SELECT 1 FROM Product p
  WHERE p.product_key NOT IN (SELECT x.product_key FROM Customer x WHERE x.customer_id = c.customer_id)
);
