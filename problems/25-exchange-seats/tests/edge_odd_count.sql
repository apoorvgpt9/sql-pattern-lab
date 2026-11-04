-- Odd number of seats: seat 5 is odd but has no seat 6 to swap with, so it keeps its student.
-- A LEAD() with no fallback, or an INNER JOIN to the partner seat, loses this row or blanks it.
INSERT INTO Seat (id, student) VALUES
  (1, 'Abbot'),
  (2, 'Doris'),
  (3, 'Emerson'),
  (4, 'Green'),
  (5, 'Jeames');

-- expect: 1,Doris | swapped with seat 2
-- expect: 2,Abbot | swapped with seat 1
-- expect: 3,Green | swapped with seat 4
-- expect: 4,Emerson | swapped with seat 3
-- expect: 5,Jeames | odd count: last seat has no partner and keeps its student
