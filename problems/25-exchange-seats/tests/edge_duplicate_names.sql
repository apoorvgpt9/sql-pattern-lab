-- Repeated student names. The swap is by seat id, never by name, so duplicates must not interfere.
INSERT INTO Seat (id, student) VALUES
  (1, 'Ann'),
  (2, 'Ann'),
  (3, 'Bob'),
  (4, 'Ann'),
  (5, 'Cy'),
  (6, 'Bob');

-- expect: 1,Ann | seat 2's student (Ann); identical to seat 1's own, so the swap is invisible here
-- expect: 2,Ann | seat 1's student (Ann)
-- expect: 3,Ann | seat 4's student (Ann); seat 3's own Bob moves to seat 4
-- expect: 4,Bob | seat 3's student (Bob)
-- expect: 5,Bob | seat 6's student (Bob)
-- expect: 6,Cy | seat 5's student (Cy)
