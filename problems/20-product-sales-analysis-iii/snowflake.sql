-- UNVERIFIED: Snowflake version of the window form (approach 02). CI cannot run Snowflake.
-- QUALIFY filters on the window result directly; no subquery is needed.
SELECT
  product_id,
  year AS first_year,
  quantity,
  price
FROM Sales
QUALIFY year = MIN(year) OVER (PARTITION BY product_id);
