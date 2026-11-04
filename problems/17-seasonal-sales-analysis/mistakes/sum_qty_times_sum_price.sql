-- breaks: edge_typical, edge_tiebreak, edge_season_boundaries
-- MISTAKE: revenue = SUM(quantity) * SUM(price). Revenue is a sum of per-row products
-- (quantity * price); multiplying the two column totals mixes rows, and gives the wrong number
-- whenever a category has more than one sale at different prices.
WITH cs AS (
  SELECT CASE WHEN MONTH(s.sale_date) IN (12,1,2) THEN 'Winter' WHEN MONTH(s.sale_date) IN (3,4,5) THEN 'Spring'
              WHEN MONTH(s.sale_date) IN (6,7,8) THEN 'Summer' ELSE 'Fall' END AS season,
         p.category, SUM(s.quantity) AS total_quantity, SUM(s.quantity) * SUM(s.price) AS total_revenue
  FROM sales s JOIN products p ON p.product_id = s.product_id GROUP BY season, p.category
), r AS (
  SELECT cs.*, ROW_NUMBER() OVER (PARTITION BY season ORDER BY total_quantity DESC, total_revenue DESC, category) AS rn FROM cs
)
SELECT season, category, total_quantity, total_revenue FROM r WHERE rn = 1 ORDER BY season;
