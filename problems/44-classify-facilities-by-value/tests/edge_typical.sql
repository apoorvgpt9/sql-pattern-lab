-- Typical: six booked facilities (2 per bucket), one facility never booked (excluded), guests
-- (memid 0) paying guestcost and members paying membercost, including a facility free for members.
INSERT INTO facilities (facid, name, membercost, guestcost, initialoutlay, monthlymaintenance) VALUES
  (1, 'Archery Range',  2.00, 10.00, 1000, 50),
  (2, 'Bowling Lane',   4.00, 12.00, 2000, 80),
  (3, 'Climbing Wall',  0.00,  8.00, 5000, 90),
  (4, 'Dance Studio',   6.00, 20.00,  800, 40),
  (5, 'Fencing Hall',  10.00, 30.00, 3000, 70),
  (6, 'Golf Simulator', 1.00,  9.00, 9000, 99),
  (7, 'Hot Tub',        3.00, 15.00, 4000, 60);
INSERT INTO bookings (bookid, facid, memid, starttime, slots) VALUES
  (1,  1, 1, '2024-05-01 09:00:00', 3),
  (2,  1, 0, '2024-05-01 10:00:00', 2),
  (3,  2, 2, '2024-05-01 11:00:00', 5),
  (4,  3, 0, '2024-05-02 09:00:00', 4),
  (5,  3, 3, '2024-05-02 12:00:00', 6),
  (6,  4, 4, '2024-05-03 09:00:00', 2),
  (7,  5, 0, '2024-05-03 10:00:00', 1),
  (8,  5, 5, '2024-05-03 11:00:00', 3),
  (9,  6, 0, '2024-05-04 09:00:00', 1),
  (10, 6, 6, '2024-05-04 10:00:00', 2);

-- Revenue: Fencing 1*30 + 3*10 = 60; Climbing 4*8 + 6*0 = 32; Archery 3*2 + 2*10 = 26;
-- Bowling 5*4 = 20; Dance 2*6 = 12; Golf 1*9 + 2*1 = 11. Six facilities -> NTILE(3) sizes 2, 2, 2.
-- expect: Climbing Wall,high | 32, 2nd by revenue; listed before Fencing Hall because rows sort by name within a bucket
-- expect: Fencing Hall,high | 60, 1st by revenue
-- expect: Archery Range,average | 26, 3rd
-- expect: Bowling Lane,average | 20, 4th
-- expect: Dance Studio,low | 12, 5th
-- expect: Golf Simulator,low | 11, 6th
-- (Hot Tub has no bookings: not a facility "with bookings", so no row)
