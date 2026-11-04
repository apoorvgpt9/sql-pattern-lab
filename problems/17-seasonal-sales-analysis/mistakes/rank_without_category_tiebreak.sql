-- breaks: edge_tiebreak
-- MISTAKE: ranks by quantity then revenue only and keeps RANK() = 1. When two categories tie on
-- both, both get rank 1 and the season appears twice. The spec requires exactly one row per season,
-- which needs the third key (category) to make the order total.
WITH cs AS (
  SELECT CASE WHEN MONTH(s.sale_date) IN (12,1,2) THEN 'Winter' WHEN MONTH(s.sale_date) IN (3,4,5) THEN 'Spring'
              WHEN MONTH(s.sale_date) IN (6,7,8) THEN 'Summer' ELSE 'Fall' END AS season,
         p.category, SUM(s.quantity) AS total_quantity, SUM(s.quantity * s.price) AS total_revenue
  FROM sales s JOIN products p ON p.product_id = s.product_id GROUP BY season, p.category
), r AS (
  SELECT cs.*, RANK() OVER (PARTITION BY season ORDER BY total_quantity DESC, total_revenue DESC) AS rk FROM cs
)
SELECT season, category, total_quantity, total_revenue FROM r WHERE rk = 1 ORDER BY season;
