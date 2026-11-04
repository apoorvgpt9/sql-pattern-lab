-- Fewer facilities than buckets: two facilities fill buckets 1 and 2; nothing is 'low'.
INSERT INTO facilities (facid, name, membercost, guestcost, initialoutlay, monthlymaintenance) VALUES
  (1, 'Archery Range', 2.00, 10.00, 100, 10),
  (2, 'Bowling Lane',  2.00, 10.00, 100, 10);
INSERT INTO bookings (bookid, facid, memid, starttime, slots) VALUES
  (1, 1, 1, '2024-07-01 09:00:00', 2),
  (2, 2, 0, '2024-07-01 10:00:00', 1);

-- Revenue: Bowling 1*10 (guest) = 10; Archery 2*2 = 4.
-- expect: Bowling Lane,high | 10, position 1 of 2 -> bucket 1
-- expect: Archery Range,average | 4, position 2 of 2 -> bucket 2 (bucket 3 stays empty)
