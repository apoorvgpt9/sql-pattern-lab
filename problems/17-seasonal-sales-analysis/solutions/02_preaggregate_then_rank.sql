-- Approach 2: shrink the big table BEFORE the join. Step 1 aggregates sales to
-- (product_id, season): at most 4 rows per product. Only then is products joined to map product ->
-- category, and the small result is re-aggregated and ranked. SUM is decomposable, so summing
-- partial sums gives the same totals as summing the raw rows.
WITH prod_season AS (
  SELECT
    product_id,
    CASE WHEN MONTH(sale_date) IN (12, 1, 2) THEN 'Winter'
         WHEN MONTH(sale_date) IN (3, 4, 5)  THEN 'Spring'
         WHEN MONTH(sale_date) IN (6, 7, 8)  THEN 'Summer'
         ELSE 'Fall' END           AS season,
    SUM(quantity)                  AS qty,
    SUM(quantity * price)          AS revenue
  FROM sales
  GROUP BY product_id, season
), cat_season AS (
  SELECT ps.season,
         p.category,
         SUM(ps.qty)     AS total_quantity,
         SUM(ps.revenue) AS total_revenue
  FROM prod_season ps
  JOIN products p ON p.product_id = ps.product_id
  GROUP BY ps.season, p.category
), ranked AS (
  SELECT cs.*,
         ROW_NUMBER() OVER (PARTITION BY season
                            ORDER BY total_quantity DESC, total_revenue DESC, category ASC) AS rn
  FROM cat_season cs
)
SELECT season, category, total_quantity, total_revenue
FROM ranked
WHERE rn = 1
ORDER BY season;
