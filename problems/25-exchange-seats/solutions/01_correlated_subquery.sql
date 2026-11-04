-- Approach 1 (brute force): for every seat, look up its partner seat with a correlated subquery.
-- Partner of an odd id is id + 1, partner of an even id is id - 1. If the partner row does not exist
-- (last odd seat) the subquery returns NULL and COALESCE keeps the seat's own student.
SELECT
  s.id,
  COALESCE(
    (SELECT t.student
       FROM Seat t
      WHERE t.id = CASE WHEN s.id % 2 = 1 THEN s.id + 1 ELSE s.id - 1 END),
    s.student) AS student
FROM Seat s
ORDER BY s.id;
