-- Approach 1 (brute force): keep a row if its year equals the product's earliest year, found with a
-- correlated MIN subquery. Equality (not "first row") keeps every row of that year.
SELECT
  s.product_id,
  s.year     AS first_year,
  s.quantity,
  s.price
FROM Sales s
WHERE s.year = (SELECT MIN(s2.year)
                  FROM Sales s2
                 WHERE s2.product_id = s.product_id);
