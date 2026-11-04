-- UNVERIFIED: Snowflake version of the as-of lookup (the idea of approaches 02/03: latest row per product on or before the date).
-- QUALIFY picks each product's latest change on or before the target date; products with no such
-- change come back through the LEFT JOIN and get the initial price 10.
SELECT
  p.product_id,
  COALESCE(a.new_price, 10) AS price
FROM (SELECT DISTINCT product_id FROM Products) p
LEFT JOIN (
  SELECT product_id, new_price
  FROM Products
  WHERE change_date <= '2019-08-16'::DATE
  QUALIFY ROW_NUMBER() OVER (PARTITION BY product_id ORDER BY change_date DESC) = 1
) a
  ON a.product_id = p.product_id;
