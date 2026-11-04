-- Approach 3 (optimal): gaps-and-islands. Filter to busy days first; then id - ROW_NUMBER() is
-- constant inside a run of consecutive ids and jumps at every gap, so it labels the island.
-- Count each island's size with a window (no join back) and keep islands of 3 or more.
WITH busy AS (
  SELECT id, visit_date, people,
         id - ROW_NUMBER() OVER (ORDER BY id) AS island
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
