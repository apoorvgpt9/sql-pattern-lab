-- breaks: edge_single_product
-- MISTAKE: the number of products written as a literal (3 here, because the example had three). The trigger phrase
-- "all the products" means "however many exist", so the total has to come from the Product table.
SELECT customer_id
FROM Customer
GROUP BY customer_id
HAVING COUNT(DISTINCT product_key) = 3;
