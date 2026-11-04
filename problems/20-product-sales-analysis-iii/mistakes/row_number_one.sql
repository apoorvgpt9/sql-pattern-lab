-- breaks: edge_same_year_rows, edge_single_rows_reused_sale_id
-- MISTAKE: ROW_NUMBER() = 1 per product returns one row per product. The spec asks for ALL rows of the
-- first year, so every additional row in that year is lost.
SELECT product_id, year AS first_year, quantity, price
FROM (SELECT product_id, year, quantity, price,
             ROW_NUMBER() OVER (PARTITION BY product_id ORDER BY year) AS rn
        FROM Sales) t
WHERE rn = 1;
