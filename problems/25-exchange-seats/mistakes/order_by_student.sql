-- breaks: edge_ordering
-- MISTAKE: sorting the result by the student column (a reflex from "alphabetical" examples) instead of by seat id.
SELECT
  id,
  COALESCE(CASE WHEN id % 2 = 1 THEN LEAD(student) OVER (ORDER BY id)
                ELSE LAG(student) OVER (ORDER BY id) END, student) AS student
FROM Seat
ORDER BY student;
