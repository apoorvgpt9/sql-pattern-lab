-- breaks: edge_season_boundaries
-- MISTAKE: groups by (year, season, category), the "natural" thing for a date. The spec says the
-- year is ignored, so December 2023 and January/February 2024 are one Winter. Here Winter is split
-- across two years and appears as two (or more) rows.
WITH cs AS (
  SELECT YEAR(s.sale_date) AS yr,
         CASE WHEN MONTH(s.sale_date) IN (12,1,2) THEN 'Winter' WHEN MONTH(s.sale_date) IN (3,4,5) THEN 'Spring'
              WHEN MONTH(s.sale_date) IN (6,7,8) THEN 'Summer' ELSE 'Fall' END AS season,
         p.category, SUM(s.quantity) AS total_quantity, SUM(s.quantity * s.price) AS total_revenue
  FROM sales s JOIN products p ON p.product_id = s.product_id GROUP BY yr, season, p.category
), r AS (
  SELECT cs.*, ROW_NUMBER() OVER (PARTITION BY yr, season ORDER BY total_quantity DESC, total_revenue DESC, category) AS rn FROM cs
)
SELECT season, category, total_quantity, total_revenue FROM r WHERE rn = 1 ORDER BY season;
