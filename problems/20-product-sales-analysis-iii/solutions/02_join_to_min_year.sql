-- Approach 2: compute each product's earliest year once with GROUP BY, then join back on
-- (product_id, year). Both keys are needed; year alone would pull in other products' rows.
SELECT
  s.product_id,
  f.first_year,
  s.quantity,
  s.price
FROM Sales s
JOIN (SELECT product_id, MIN(year) AS first_year
        FROM Sales
       GROUP BY product_id) f
  ON  f.product_id = s.product_id
  AND f.first_year = s.year;
