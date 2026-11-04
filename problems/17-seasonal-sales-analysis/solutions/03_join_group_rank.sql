-- Approach 3 (optimal): join sales to products first, aggregate to (season, category), then rank the
-- categories inside each season. ROW_NUMBER is right here (not RANK) because the third sort key
-- (category) makes the ordering total: the spec wants exactly one row per season.
WITH cat_season AS (
  SELECT
    CASE WHEN MONTH(s.sale_date) IN (12, 1, 2) THEN 'Winter'
         WHEN MONTH(s.sale_date) IN (3, 4, 5)  THEN 'Spring'
         WHEN MONTH(s.sale_date) IN (6, 7, 8)  THEN 'Summer'
         ELSE 'Fall' END                AS season,
    p.category,
    SUM(s.quantity)                     AS total_quantity,
    SUM(s.quantity * s.price)           AS total_revenue
  FROM sales s
  JOIN products p ON p.product_id = s.product_id
  GROUP BY season, p.category
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
