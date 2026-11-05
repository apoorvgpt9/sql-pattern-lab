-- breaks: edge_null_id
-- MISTAKE: no id IS NOT NULL filter. id - ROW_NUMBER() is NULL for every NULL-id row, and
-- PARTITION BY puts all NULLs in one partition, so three busy NULL-id days form a fake island of size 3.
WITH busy AS (
  SELECT id, visit_date, people,
         id - CAST(ROW_NUMBER() OVER (ORDER BY id) AS SIGNED) AS island
  FROM Stadium
  WHERE people >= 100
),
sized AS (
  SELECT id, visit_date, people,
         COUNT(*) OVER (PARTITION BY island) AS island_size
  FROM busy
)
SELECT id, visit_date, people
FROM sized
WHERE island_size >= 3
ORDER BY visit_date;
