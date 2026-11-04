-- Ordering test for (bucket ASC, name ASC). Within every bucket the name order is the reverse of
-- the revenue order, and the label text sorts differently from the bucket number
-- ('average' < 'high' < 'low' alphabetically). facid order matches neither.
INSERT INTO facilities (facid, name, membercost, guestcost, initialoutlay, monthlymaintenance) VALUES
  (11, 'Alpha',   1.00, 1.00, 100, 10),
  (12, 'Foxtrot', 1.00, 1.00, 100, 10),
  (13, 'Charlie', 1.00, 1.00, 100, 10),
  (14, 'Echo',    1.00, 1.00, 100, 10),
  (15, 'Bravo',   1.00, 1.00, 100, 10),
  (16, 'Delta',   1.00, 1.00, 100, 10);
INSERT INTO bookings (bookid, facid, memid, starttime, slots) VALUES
  (1, 11, 1, '2024-09-01 09:00:00', 1),
  (2, 15, 1, '2024-09-01 10:00:00', 2),
  (3, 13, 1, '2024-09-01 11:00:00', 3),
  (4, 16, 1, '2024-09-01 12:00:00', 4),
  (5, 14, 1, '2024-09-01 13:00:00', 5),
  (6, 12, 1, '2024-09-01 14:00:00', 6);

-- Revenue = slots * 1: Foxtrot 6, Echo 5, Delta 4, Charlie 3, Bravo 2, Alpha 1. Sizes 2, 2, 2.
-- expect: Echo,high | 5, bucket 1; before Foxtrot by name although Foxtrot earns more
-- expect: Foxtrot,high | 6, bucket 1
-- expect: Charlie,average | 3, bucket 2; 'average' rows come after all 'high' rows (bucket order, not label text)
-- expect: Delta,average | 4, bucket 2
-- expect: Alpha,low | 1, bucket 3
-- expect: Bravo,low | 2, bucket 3
