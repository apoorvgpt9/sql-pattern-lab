-- breaks: edge_typical, edge_duplicates
-- MISTAKE: HAVING COUNT(product_key) = total, without DISTINCT. A customer who bought one product three times looks like
-- a customer who bought three products (false positive, edge_duplicates); a customer who bought everything plus a
-- repeat has more rows than products and is rejected by the "=" (false negative, edge_typical).
SELECT customer_id
FROM Customer
GROUP BY customer_id
HAVING COUNT(product_key) = (SELECT COUNT(*) FROM Product);
