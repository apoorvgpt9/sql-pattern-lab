-- Two facilities tie on revenue (30) across the high/average boundary. The spec leaves the order of
-- ties undefined; this repo fixes it as facid ASC (README "Assumptions"). The names run opposite
-- to facid, so a name-based tie-break would give the other answer.
INSERT INTO facilities (facid, name, membercost, guestcost, initialoutlay, monthlymaintenance) VALUES
  (1, 'Zip Line',      3.00,  6.00, 100, 10),
  (2, 'Yoga Studio',   3.00,  6.00, 100, 10),
  (3, 'Archery Range', 5.00, 10.00, 100, 10),
  (4, 'Bowling Lane',  1.00,  2.00, 100, 10);
INSERT INTO bookings (bookid, facid, memid, starttime, slots) VALUES
  (1, 1, 1, '2024-08-01 09:00:00', 10),
  (2, 2, 0, '2024-08-01 10:00:00', 5),
  (3, 3, 1, '2024-08-01 11:00:00', 10),
  (4, 4, 2, '2024-08-01 12:00:00', 10);

-- Revenue: Archery 10*5 = 50; Zip Line 10*3 = 30; Yoga 5*6 (guest) = 30; Bowling 10*1 = 10.
-- Positions with tie-break facid ASC: Archery 1, Zip Line 2 (facid 1), Yoga 3 (facid 2), Bowling 4. Sizes 2, 1, 1.
-- expect: Archery Range,high | 50, position 1
-- expect: Zip Line,high | 30, position 2: wins the tie with Yoga Studio on facid 1 < 2
-- expect: Yoga Studio,average | 30, position 3: same revenue as Zip Line, different bucket (NTILE is positional)
-- expect: Bowling Lane,low | 10, position 4
