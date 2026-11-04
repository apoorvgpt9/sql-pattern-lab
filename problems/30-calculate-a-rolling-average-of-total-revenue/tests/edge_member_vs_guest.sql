-- One day (2012-08-10) with all four combinations: guest at a facility with member price 0, member at that facility (0),
-- guest at a facility with a fractional price, and a member there. memid 0 is the shared GUEST account.
-- Day total = 20.00 + 0.00 + 35.00 + 10.50 = 65.50. It is inside the windows of Aug 10 .. Aug 24.
INSERT INTO facilities (facid, name, membercost, guestcost, initialoutlay, monthlymaintenance) VALUES
  (2, 'Cue Room', 0.00, 5.00, 400, 15),
  (3, 'Wall Court', 3.50, 17.50, 5000, 80);

INSERT INTO bookings (bookid, facid, memid, starttime, slots) VALUES
  (1, 2, 0, '2012-08-10 09:00:00', 4),
  (2, 2, 4, '2012-08-10 10:00:00', 8),
  (3, 3, 0, '2012-08-10 11:00:00', 2),
  (4, 3, 6, '2012-08-10 12:00:00', 3);

-- expect: 2012-08-01,0 | window Jul 18 - Aug 01: no bookings; 0/15 = 0
-- expect: 2012-08-02,0 | window Jul 19 - Aug 02: no bookings; 0/15 = 0
-- expect: 2012-08-03,0 | window Jul 20 - Aug 03: no bookings; 0/15 = 0
-- expect: 2012-08-04,0 | window Jul 21 - Aug 04: no bookings; 0/15 = 0
-- expect: 2012-08-05,0 | window Jul 22 - Aug 05: no bookings; 0/15 = 0
-- expect: 2012-08-06,0 | window Jul 23 - Aug 06: no bookings; 0/15 = 0
-- expect: 2012-08-07,0 | window Jul 24 - Aug 07: no bookings; 0/15 = 0
-- expect: 2012-08-08,0 | window Jul 25 - Aug 08: no bookings; 0/15 = 0
-- expect: 2012-08-09,0 | window Jul 26 - Aug 09: no bookings; 0/15 = 0
-- expect: 2012-08-10,4.366667 | window Jul 27 - Aug 10: Aug 10 = 65.50; 65.50/15 = 4.366667
-- expect: 2012-08-11,4.366667 | window Jul 28 - Aug 11: Aug 10 = 65.50; 65.50/15 = 4.366667
-- expect: 2012-08-12,4.366667 | window Jul 29 - Aug 12: Aug 10 = 65.50; 65.50/15 = 4.366667
-- expect: 2012-08-13,4.366667 | window Jul 30 - Aug 13: Aug 10 = 65.50; 65.50/15 = 4.366667
-- expect: 2012-08-14,4.366667 | window Jul 31 - Aug 14: Aug 10 = 65.50; 65.50/15 = 4.366667
-- expect: 2012-08-15,4.366667 | window Aug 01 - Aug 15: Aug 10 = 65.50; 65.50/15 = 4.366667
-- expect: 2012-08-16,4.366667 | window Aug 02 - Aug 16: Aug 10 = 65.50; 65.50/15 = 4.366667
-- expect: 2012-08-17,4.366667 | window Aug 03 - Aug 17: Aug 10 = 65.50; 65.50/15 = 4.366667
-- expect: 2012-08-18,4.366667 | window Aug 04 - Aug 18: Aug 10 = 65.50; 65.50/15 = 4.366667
-- expect: 2012-08-19,4.366667 | window Aug 05 - Aug 19: Aug 10 = 65.50; 65.50/15 = 4.366667
-- expect: 2012-08-20,4.366667 | window Aug 06 - Aug 20: Aug 10 = 65.50; 65.50/15 = 4.366667
-- expect: 2012-08-21,4.366667 | window Aug 07 - Aug 21: Aug 10 = 65.50; 65.50/15 = 4.366667
-- expect: 2012-08-22,4.366667 | window Aug 08 - Aug 22: Aug 10 = 65.50; 65.50/15 = 4.366667
-- expect: 2012-08-23,4.366667 | window Aug 09 - Aug 23: Aug 10 = 65.50; 65.50/15 = 4.366667
-- expect: 2012-08-24,4.366667 | window Aug 10 - Aug 24: Aug 10 = 65.50; 65.50/15 = 4.366667
-- expect: 2012-08-25,0 | window Aug 11 - Aug 25: no bookings; 0/15 = 0
-- expect: 2012-08-26,0 | window Aug 12 - Aug 26: no bookings; 0/15 = 0
-- expect: 2012-08-27,0 | window Aug 13 - Aug 27: no bookings; 0/15 = 0
-- expect: 2012-08-28,0 | window Aug 14 - Aug 28: no bookings; 0/15 = 0
-- expect: 2012-08-29,0 | window Aug 15 - Aug 29: no bookings; 0/15 = 0
-- expect: 2012-08-30,0 | window Aug 16 - Aug 30: no bookings; 0/15 = 0
-- expect: 2012-08-31,0 | window Aug 17 - Aug 31: no bookings; 0/15 = 0
