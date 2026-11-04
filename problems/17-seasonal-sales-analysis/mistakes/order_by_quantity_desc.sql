-- breaks: edge_typical, edge_tiebreak, edge_season_boundaries, edge_ordering
-- MISTAKE: orders the result by the measure instead of by season. The ranking and the totals are
-- right; only the output order is wrong, and the spec fixes it as season ascending.
WITH cs AS (
  SELECT CASE WHEN MONTH(s.sale_date) IN (12,1,2) THEN 'Winter' WHEN MONTH(s.sale_date) IN (3,4,5) THEN 'Spring'
              WHEN MONTH(s.sale_date) IN (6,7,8) THEN 'Summer' ELSE 'Fall' END AS season,
         p.category, SUM(s.quantity) AS total_quantity, SUM(s.quantity * s.price) AS total_revenue
  FROM sales s JOIN products p ON p.product_id = s.product_id GROUP BY season, p.category
), r AS (
  SELECT cs.*, ROW_NUMBER() OVER (PARTITION BY season ORDER BY total_quantity DESC, total_revenue DESC, category) AS rn FROM cs
)
SELECT season, category, total_quantity, total_revenue FROM r WHERE rn = 1
ORDER BY total_quantity DESC;
