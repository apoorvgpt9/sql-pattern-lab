-- breaks: edge_typical, edge_boundary_100, edge_nulls
-- MISTAKE: numbering ALL rows and filtering afterwards. With consecutive ids, id - ROW_NUMBER()
-- is the same for every row, so the whole table is one "island" and every busy day comes back.
-- The filter "people >= 100" has to run before the rows are numbered.
WITH numbered AS (
  SELECT id, visit_date, people, id - ROW_NUMBER() OVER (ORDER BY id) AS island
  FROM Stadium
),
sized AS (
  SELECT id, visit_date, people, island,
         SUM(people >= 100) OVER (PARTITION BY island) AS busy_in_island
  FROM numbered
)
SELECT id, visit_date, people
FROM sized
WHERE people >= 100 AND busy_in_island >= 3
ORDER BY visit_date;
