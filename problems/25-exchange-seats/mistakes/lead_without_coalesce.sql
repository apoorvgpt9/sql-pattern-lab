-- breaks: edge_odd_count, edge_single_seat
-- MISTAKE: LEAD()/LAG() with no fallback. For the last odd seat LEAD returns NULL, so the seat is
-- kept but its student is blanked.
SELECT
  id,
  CASE WHEN id % 2 = 1 THEN LEAD(student) OVER (ORDER BY id)
       ELSE LAG(student) OVER (ORDER BY id)
  END AS student
FROM Seat
ORDER BY id;
