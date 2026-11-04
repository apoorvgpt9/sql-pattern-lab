-- breaks: edge_typical, edge_year_vs_sale_id, edge_single_rows_reused_sale_id, edge_same_year_rows
-- MISTAKE: takes the earliest year of the whole table, not of each product. Only products that sold in
-- that one year survive.
SELECT product_id, year AS first_year, quantity, price
FROM Sales
WHERE year = (SELECT MIN(year) FROM Sales);
