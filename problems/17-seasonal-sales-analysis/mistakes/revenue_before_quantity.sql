-- breaks: edge_tiebreak
-- MISTAKE: swaps the first two sort keys (revenue, then quantity). The spec says quantity is the
-- primary measure; revenue only breaks quantity ties. Fall in edge_tiebreak is the witness.
WITH cs AS (
  SELECT CASE WHEN MONTH(s.sale_date) IN (12,1,2) THEN 'Winter' WHEN MONTH(s.sale_date) IN (3,4,5) THEN 'Spring'
              WHEN MONTH(s.sale_date) IN (6,7,8) THEN 'Summer' ELSE 'Fall' END AS season,
         p.category, SUM(s.quantity) AS total_quantity, SUM(s.quantity * s.price) AS total_revenue
  FROM sales s JOIN products p ON p.product_id = s.product_id GROUP BY season, p.category
), r AS (
  SELECT cs.*, ROW_NUMBER() OVER (PARTITION BY season ORDER BY total_revenue DESC, total_quantity DESC, category) AS rn FROM cs
)
SELECT season, category, total_quantity, total_revenue FROM r WHERE rn = 1 ORDER BY season;
