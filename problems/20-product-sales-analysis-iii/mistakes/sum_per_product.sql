-- breaks: edge_same_year_rows, edge_single_rows_reused_sale_id
-- MISTAKE: reads "all sales entries for that product" as a total and groups: one row per product with
-- summed quantity and price. The spec wants the individual first-year rows.
SELECT s.product_id, s.year AS first_year, SUM(s.quantity) AS quantity, SUM(s.price) AS price
FROM Sales s
JOIN (SELECT product_id, MIN(year) AS first_year FROM Sales GROUP BY product_id) f
  ON f.product_id = s.product_id AND f.first_year = s.year
GROUP BY s.product_id, s.year;
