-- Approach 3 (optimal): do not move students into seats by lookup; move each student to its new seat id.
-- Each input row maps to exactly one output row with a new id, so the whole query is a per-row
-- computation: no join, no window, no dependence between rows except one scalar (the largest id).
-- Odd id -> id + 1, even id -> id - 1, except the last seat when the count is odd (stays put).
WITH moved AS (
  SELECT
    CASE WHEN id % 2 = 0                          THEN id - 1
         WHEN id < (SELECT MAX(id) FROM Seat)     THEN id + 1
         ELSE id
    END AS id,
    student
  FROM Seat
)
SELECT id, student
FROM moved
ORDER BY id;
