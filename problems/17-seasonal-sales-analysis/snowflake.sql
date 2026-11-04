-- UNVERIFIED: Snowflake version of the optimal approach (03). CI cannot run Snowflake.
-- QUALIFY replaces the ranked CTE; CASE on MONTH() is unchanged.
WITH prod_season AS (
  SELECT
    product_id,
    CASE WHEN MONTH(sale_date) IN (12, 1, 2) THEN 'Winter'
         WHEN MONTH(sale_date) IN (3, 4, 5)  THEN 'Spring'
         WHEN MONTH(sale_date) IN (6, 7, 8)  THEN 'Summer'
         ELSE 'Fall' END        AS season,
    SUM(quantity)               AS qty,
    SUM(quantity * price)       AS revenue
  FROM sales
  GROUP BY product_id, season
)
SELECT
  ps.season,
  p.category,
  SUM(ps.qty)     AS total_quantity,
  SUM(ps.revenue) AS total_revenue
FROM prod_season ps
JOIN products p ON p.product_id = ps.product_id
GROUP BY ps.season, p.category
QUALIFY ROW_NUMBER() OVER (PARTITION BY ps.season
                           ORDER BY SUM(ps.qty) DESC, SUM(ps.revenue) DESC, p.category ASC) = 1
ORDER BY ps.season;
