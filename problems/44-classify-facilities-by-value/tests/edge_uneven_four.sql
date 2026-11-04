-- Four facilities cannot split evenly into three groups. NTILE semantics: the extra row goes to the
-- EARLIER bucket, so the sizes are 2, 1, 1 (not 1, 1, 2).
INSERT INTO facilities (facid, name, membercost, guestcost, initialoutlay, monthlymaintenance) VALUES
  (1, 'Archery Range', 5.00, 10.00, 100, 10),
  (2, 'Bowling Lane',  5.00, 10.00, 100, 10),
  (3, 'Climbing Wall', 5.00, 10.00, 100, 10),
  (4, 'Dance Studio',  5.00, 10.00, 100, 10);
INSERT INTO bookings (bookid, facid, memid, starttime, slots) VALUES
  (1, 1, 1, '2024-06-01 09:00:00', 4),
  (2, 2, 2, '2024-06-01 10:00:00', 8),
  (3, 3, 3, '2024-06-01 11:00:00', 2),
  (4, 4, 0, '2024-06-01 12:00:00', 3);

-- Revenue: Bowling 8*5 = 40; Dance 3*10 (guest) = 30; Archery 4*5 = 20; Climbing 2*5 = 10.
-- expect: Bowling Lane,high | 40, position 1 of 4
-- expect: Dance Studio,high | 30, position 2: the first bucket gets the extra row (sizes 2, 1, 1)
-- expect: Archery Range,average | 20, position 3
-- expect: Climbing Wall,low | 10, position 4
