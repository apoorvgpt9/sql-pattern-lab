-- Even number of seats: every seat has a partner (1<->2, 3<->4).
INSERT INTO Seat (id, student) VALUES
  (1, 'Abbot'),
  (2, 'Doris'),
  (3, 'Emerson'),
  (4, 'Green');

-- expect: 1,Doris | seat 1 takes the student of seat 2
-- expect: 2,Abbot | seat 2 takes the student of seat 1
-- expect: 3,Green | seat 3 takes the student of seat 4
-- expect: 4,Emerson | seat 4 takes the student of seat 3
