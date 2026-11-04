-- breaks: edge_boundary_100
-- MISTAKE: "greater than or equal to 100" written as > 100. Days with exactly 100 people drop out.
WITH busy AS (
  SELECT id, visit_date, people, id - ROW_NUMBER() OVER (ORDER BY id) AS island
  FROM Stadium
  WHERE people > 100
),
sized AS (
  SELECT id, visit_date, people, COUNT(*) OVER (PARTITION BY island) AS island_size FROM busy
)
SELECT id, visit_date, people FROM sized WHERE island_size >= 3
ORDER BY visit_date;
