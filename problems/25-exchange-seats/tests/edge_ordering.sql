-- Tests the output order itself. Rows are inserted out of id order, and the names are chosen so that
-- sorting the OUTPUT by student gives a different order from sorting it by id.
-- Output must be ascending by id (exact order is compared for this problem).
INSERT INTO Seat (id, student) VALUES
  (4, 'Dee'),
  (2, 'Ann'),
  (1, 'Cho'),
  (3, 'Bea');

-- expect: 1,Ann | seat 2's student; first row because ordering is by id
-- expect: 2,Cho | seat 1's student; by student order Cho would come third
-- expect: 3,Dee | seat 4's student
-- expect: 4,Bea | seat 3's student; by student order Bea would come second
