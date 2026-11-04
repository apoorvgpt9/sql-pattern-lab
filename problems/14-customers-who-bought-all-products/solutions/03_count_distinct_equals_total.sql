-- Approach 3 (optimal): one pass. A customer bought everything exactly when the number of DISTINCT products they bought
-- equals the number of products that exist. COUNT(DISTINCT) ignores NULL and ignores repeated rows.
-- Valid because every non-NULL product_key in Customer exists in Product (spec): the customer's distinct keys
-- are then a subset of the products, and a subset of full size is the whole set.
SELECT customer_id
FROM Customer
GROUP BY customer_id
HAVING COUNT(DISTINCT product_key) = (SELECT COUNT(*) FROM Product);
