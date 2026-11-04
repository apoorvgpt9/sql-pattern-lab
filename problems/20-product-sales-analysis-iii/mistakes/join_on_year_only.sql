-- breaks: edge_typical
-- MISTAKE: joins the per-product earliest years back on year alone. Any product that sold in a year that
-- happens to be SOME product's first year is returned for that year, including rows that are not its own first.
SELECT s.product_id, f.first_year, s.quantity, s.price
FROM Sales s
JOIN (SELECT product_id, MIN(year) AS first_year FROM Sales GROUP BY product_id) f
  ON f.first_year = s.year;
