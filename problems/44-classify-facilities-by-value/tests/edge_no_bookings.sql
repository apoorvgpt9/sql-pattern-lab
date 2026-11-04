-- Facilities exist but nothing was ever booked: no facility qualifies.
INSERT INTO facilities (facid, name, membercost, guestcost, initialoutlay, monthlymaintenance) VALUES
  (1, 'Archery Range', 2.00, 10.00, 100, 10),
  (2, 'Bowling Lane',  4.00, 12.00, 100, 10),
  (3, 'Climbing Wall', 0.00,  8.00, 100, 10);

-- expect-empty: only facilities with bookings are classified, and there are no bookings
