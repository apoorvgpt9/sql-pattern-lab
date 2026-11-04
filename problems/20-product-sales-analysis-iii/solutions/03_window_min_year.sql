-- Approach 3 (optimal): one pass with MIN(year) OVER (PARTITION BY product_id), which puts the product's
-- earliest year on every row, then keep the rows that equal it. No join back, no ordering inside the
-- partition (RANK() = 1 would need ORDER BY year; this needs only the partition).
SELECT product_id, first_year, quantity, price
FROM (
  SELECT
    product_id,
    year                                       AS yr,
    MIN(year) OVER (PARTITION BY product_id)   AS first_year,
    quantity,
    price
  FROM Sales
) t
WHERE yr = first_year;
