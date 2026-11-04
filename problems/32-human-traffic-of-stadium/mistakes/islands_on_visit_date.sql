-- breaks: edge_id_vs_date_gaps
-- MISTAKE: the island key built from visit_date instead of id. The wording says consecutive ids;
-- a skipped date inside consecutive ids must not split a run, and consecutive dates across a
-- missing id must not join one.
WITH busy AS (
  SELECT id, visit_date, people,
         DATE_SUB(visit_date, INTERVAL ROW_NUMBER() OVER (ORDER BY visit_date) DAY) AS island
  FROM Stadium
  WHERE people >= 100
),
sized AS (
  SELECT id, visit_date, people, COUNT(*) OVER (PARTITION BY island) AS island_size
  FROM busy
)
SELECT id, visit_date, people FROM sized WHERE island_size >= 3
ORDER BY visit_date;
