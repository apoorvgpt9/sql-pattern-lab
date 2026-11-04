-- breaks: edge_typical, edge_tiebreak, edge_season_boundaries, edge_ordering
-- MISTAKE: writes Winter as BETWEEN 12 AND 2. BETWEEN needs low AND high; 12 AND 2 is an empty
-- range, so December, January and February match no branch and get a NULL season.
WITH cs AS (
  SELECT CASE WHEN MONTH(s.sale_date) BETWEEN 12 AND 2 THEN 'Winter' WHEN MONTH(s.sale_date) BETWEEN 3 AND 5 THEN 'Spring'
              WHEN MONTH(s.sale_date) BETWEEN 6 AND 8 THEN 'Summer' WHEN MONTH(s.sale_date) BETWEEN 9 AND 11 THEN 'Fall' END AS season,
         p.category, SUM(s.quantity) AS total_quantity, SUM(s.quantity * s.price) AS total_revenue
  FROM sales s JOIN products p ON p.product_id = s.product_id GROUP BY season, p.category
), r AS (
  SELECT cs.*, ROW_NUMBER() OVER (PARTITION BY season ORDER BY total_quantity DESC, total_revenue DESC, category) AS rn FROM cs
)
SELECT season, category, total_quantity, total_revenue FROM r WHERE rn = 1 ORDER BY season;
