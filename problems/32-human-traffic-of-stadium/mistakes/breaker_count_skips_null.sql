-- breaks: edge_nulls
-- MISTAKE: label islands by a running count of quiet rows, written as SUM(people < 100).
-- For a NULL count, people < 100 is NULL and SUM skips it, so the unknown day is not treated as
-- a break: rows 1, 3, 4, 5 land in one island of 4. (The CASE ... ELSE 1 form counts NULL as a
-- break; the comparison form does not.)
WITH flagged AS (
  SELECT id, visit_date, people,
         SUM(people < 100) OVER (ORDER BY id) AS quiet_before
  FROM Stadium
),
sized AS (
  SELECT id, visit_date, people, COUNT(*) OVER (PARTITION BY quiet_before) AS island_size
  FROM flagged
  WHERE people >= 100
)
SELECT id, visit_date, people FROM sized WHERE island_size >= 3
ORDER BY visit_date;
