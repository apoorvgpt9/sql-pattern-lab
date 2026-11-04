-- breaks: edge_typical, edge_none_qualify
-- MISTAKE: join to Product and stop. That returns every customer who bought ANY product; "all" needs a comparison of counts
-- or a double negation.
SELECT DISTINCT c.customer_id
FROM Customer c
JOIN Product p ON p.product_key = c.product_key;
