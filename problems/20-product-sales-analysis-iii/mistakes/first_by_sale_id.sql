-- breaks: edge_typical, edge_year_vs_sale_id, edge_same_year_rows, edge_single_rows_reused_sale_id
-- MISTAKE: treats the smallest sale_id as the "first" sale. sale_id is only half of the key and says
-- nothing about the year, so a product whose later-year row has the smaller sale_id is answered wrongly.
SELECT s.product_id, s.year AS first_year, s.quantity, s.price
FROM Sales s
WHERE s.sale_id = (SELECT MIN(s2.sale_id) FROM Sales s2 WHERE s2.product_id = s.product_id);
