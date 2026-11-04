-- breaks: edge_null_product_key
-- MISTAKE: dedupe the (customer, product) rows first, then COUNT(*). The NULL product_key survives the DISTINCT as one more row,
-- so a customer with two real products and a NULL row looks like they have three.
SELECT customer_id
FROM (SELECT DISTINCT customer_id, product_key FROM Customer) d
GROUP BY customer_id
HAVING COUNT(*) = (SELECT COUNT(*) FROM Product);
