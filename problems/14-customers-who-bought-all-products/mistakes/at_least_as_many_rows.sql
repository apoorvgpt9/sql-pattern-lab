-- breaks: edge_duplicates, edge_none_qualify
-- MISTAKE: ">=" on the raw row count, to "allow for duplicates". Duplicate rows then qualify customers who are missing products.
SELECT customer_id
FROM Customer
GROUP BY customer_id
HAVING COUNT(*) >= (SELECT COUNT(*) FROM Product);
