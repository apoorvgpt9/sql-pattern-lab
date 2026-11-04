-- Approach 1 (brute force): aggregate to (season, category), then keep a row only if NO other
-- category in the same season beats it under the three-level rule. A "self anti-join": no ranking
-- function, just "nobody is better than me". The CTE is read twice (outer row and the NOT EXISTS probe).
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
)
SELECT a.season, a.category, a.total_quantity, a.total_revenue
FROM cat_season a
WHERE NOT EXISTS (
  SELECT 1
  FROM cat_season b
  WHERE b.season = a.season
    AND ( b.total_quantity > a.total_quantity
       OR (b.total_quantity = a.total_quantity AND b.total_revenue > a.total_revenue)
       OR (b.total_quantity = a.total_quantity AND b.total_revenue = a.total_revenue
           AND b.category < a.category) )
)
ORDER BY a.season;
