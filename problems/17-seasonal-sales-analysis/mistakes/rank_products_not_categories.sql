-- breaks: edge_typical
-- MISTAKE: ranks individual products and reports their category, skipping the (season, category)
-- aggregation. "Most popular category" is a category total: two mid-sized products of one category
-- can outsell a single big product of another.
WITH ps AS (
  SELECT CASE WHEN MONTH(s.sale_date) IN (12,1,2) THEN 'Winter' WHEN MONTH(s.sale_date) IN (3,4,5) THEN 'Spring'
              WHEN MONTH(s.sale_date) IN (6,7,8) THEN 'Summer' ELSE 'Fall' END AS season,
         p.category, s.product_id, SUM(s.quantity) AS total_quantity, SUM(s.quantity * s.price) AS total_revenue
  FROM sales s JOIN products p ON p.product_id = s.product_id GROUP BY season, p.category, s.product_id
), r AS (
  SELECT ps.*, ROW_NUMBER() OVER (PARTITION BY season ORDER BY total_quantity DESC, total_revenue DESC, category) AS rn FROM ps
)
SELECT season, category, total_quantity, total_revenue FROM r WHERE rn = 1 ORDER BY season;
