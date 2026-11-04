-- Approach 3 (optimal): one scan. A window MAX(CASE ...) puts "the product's latest change date on or
-- before the target date" on every row of the product (NULL when there is none). A GROUP BY then keeps
-- the price of the row on exactly that date; if there is none, the conditional MAX is NULL and COALESCE
-- supplies 10. Every product has at least one row, so every product gets exactly one output row.
SELECT
  product_id,
  COALESCE(MAX(CASE WHEN change_date = last_date THEN new_price END), 10) AS price
FROM (
  SELECT
    product_id,
    new_price,
    change_date,
    MAX(CASE WHEN change_date <= '2019-08-16' THEN change_date END)
      OVER (PARTITION BY product_id) AS last_date
  FROM Products
) t
GROUP BY product_id;
