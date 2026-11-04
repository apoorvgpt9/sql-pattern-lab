-- Approach 2: build the full customer x product grid, mark which cells were bought, and keep customers with no empty cell.
-- The grid is the scaffold of problem 09, applied to a matrix. Correct, and it materialises customers x products rows.
-- bought is deduplicated first so that the LEFT JOIN cannot multiply grid rows when a purchase repeats.
WITH bought AS (
  SELECT DISTINCT customer_id, product_key FROM Customer
),
grid AS (
  SELECT c.customer_id, p.product_key
  FROM (SELECT DISTINCT customer_id FROM Customer) c
  CROSS JOIN Product p
)
SELECT g.customer_id
FROM grid g
LEFT JOIN bought b
  ON b.customer_id = g.customer_id AND b.product_key = g.product_key
GROUP BY g.customer_id
HAVING COUNT(b.product_key) = COUNT(*);   -- every grid cell found a purchase
