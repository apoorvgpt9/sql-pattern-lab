-- breaks: edge_same_year_rows
-- MISTAKE: adds DISTINCT "to be safe". Two sales that differ only in sale_id project to the same output
-- row, and DISTINCT merges them, but the spec returns one row per Sales row.
SELECT DISTINCT s.product_id, s.year AS first_year, s.quantity, s.price
FROM Sales s
JOIN (SELECT product_id, MIN(year) AS first_year FROM Sales GROUP BY product_id) f
  ON f.product_id = s.product_id AND f.first_year = s.year;
