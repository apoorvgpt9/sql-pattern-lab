-- UNVERIFIED: Snowflake version of the optimal approach (03). CI cannot run Snowflake.
-- QUALIFY filters on the window result directly; no subquery is needed.
SELECT
  product_id,
  year AS first_year,
  quantity,
  price
FROM Sales
QUALIFY year = MIN(year) OVER (PARTITION BY product_id);
