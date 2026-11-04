-- breaks: edge_orphan_sales
-- MISTAKE: LEFT JOINs products "so no sale is lost". A sale of an unknown product gets a NULL
-- category, forms its own (season, NULL) group, and can win the season (here 500 units).
WITH cs AS (
  SELECT CASE WHEN MONTH(s.sale_date) IN (12,1,2) THEN 'Winter' WHEN MONTH(s.sale_date) IN (3,4,5) THEN 'Spring'
              WHEN MONTH(s.sale_date) IN (6,7,8) THEN 'Summer' ELSE 'Fall' END AS season,
         p.category, SUM(s.quantity) AS total_quantity, SUM(s.quantity * s.price) AS total_revenue
  FROM sales s LEFT JOIN products p ON p.product_id = s.product_id GROUP BY season, p.category
), r AS (
  SELECT cs.*, ROW_NUMBER() OVER (PARTITION BY season ORDER BY total_quantity DESC, total_revenue DESC, category) AS rn FROM cs
)
SELECT season, category, total_quantity, total_revenue FROM r WHERE rn = 1 ORDER BY season;
