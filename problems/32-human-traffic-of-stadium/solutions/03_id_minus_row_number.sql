-- Approach 3 (optimal): gaps-and-islands. Filter to busy days first; then id - ROW_NUMBER() is
-- constant inside a run of consecutive ids and jumps at every gap, so it labels the island.
-- Count each island's size with a window (no join back) and keep islands of 3 or more.
-- CAST(... AS SIGNED): ROW_NUMBER() is BIGINT UNSIGNED in MySQL, so a bare id - ROW_NUMBER() is unsigned
-- arithmetic and raises an out-of-range error as soon as id < row number (ids from 0, negative ids).
-- id IS NOT NULL: a NULL id cannot be consecutive with anything, and all NULL labels would share one partition.
WITH busy AS (
  SELECT id, visit_date, people,
         id - CAST(ROW_NUMBER() OVER (ORDER BY id) AS SIGNED) AS island
  FROM Stadium
  WHERE people >= 100 AND id IS NOT NULL
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
