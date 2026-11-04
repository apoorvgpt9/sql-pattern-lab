-- Tests the output order (date ascending). Bookings are inserted out of date order; the cost is 5.00 per guest slot.
-- Aug 3: 3 slots = 15.00, Aug 12: 6 slots = 30.00, Aug 20: 9 slots = 45.00. Window = the date and the 14 days before it.
INSERT INTO facilities (facid, name, membercost, guestcost, initialoutlay, monthlymaintenance) VALUES
  (2, 'Cue Room', 0.00, 5.00, 400, 15);

INSERT INTO bookings (bookid, facid, memid, starttime, slots) VALUES
  (1, 2, 0, '2012-08-20 14:00:00', 9),
  (2, 2, 0, '2012-08-03 14:00:00', 3),
  (3, 2, 0, '2012-08-12 14:00:00', 6);

-- expect: 2012-08-01,0 | window Jul 18 - Aug 01: no bookings; 0/15 = 0
-- expect: 2012-08-02,0 | window Jul 19 - Aug 02: no bookings; 0/15 = 0
-- expect: 2012-08-03,1 | window Jul 20 - Aug 03: Aug 03 = 15.00; 15.00/15 = 1
-- expect: 2012-08-04,1 | window Jul 21 - Aug 04: Aug 03 = 15.00; 15.00/15 = 1
-- expect: 2012-08-05,1 | window Jul 22 - Aug 05: Aug 03 = 15.00; 15.00/15 = 1
-- expect: 2012-08-06,1 | window Jul 23 - Aug 06: Aug 03 = 15.00; 15.00/15 = 1
-- expect: 2012-08-07,1 | window Jul 24 - Aug 07: Aug 03 = 15.00; 15.00/15 = 1
-- expect: 2012-08-08,1 | window Jul 25 - Aug 08: Aug 03 = 15.00; 15.00/15 = 1
-- expect: 2012-08-09,1 | window Jul 26 - Aug 09: Aug 03 = 15.00; 15.00/15 = 1
-- expect: 2012-08-10,1 | window Jul 27 - Aug 10: Aug 03 = 15.00; 15.00/15 = 1
-- expect: 2012-08-11,1 | window Jul 28 - Aug 11: Aug 03 = 15.00; 15.00/15 = 1
-- expect: 2012-08-12,3 | window Jul 29 - Aug 12: Aug 03 = 15.00, Aug 12 = 30.00; 45.00/15 = 3
-- expect: 2012-08-13,3 | window Jul 30 - Aug 13: Aug 03 = 15.00, Aug 12 = 30.00; 45.00/15 = 3
-- expect: 2012-08-14,3 | window Jul 31 - Aug 14: Aug 03 = 15.00, Aug 12 = 30.00; 45.00/15 = 3
-- expect: 2012-08-15,3 | window Aug 01 - Aug 15: Aug 03 = 15.00, Aug 12 = 30.00; 45.00/15 = 3
-- expect: 2012-08-16,3 | window Aug 02 - Aug 16: Aug 03 = 15.00, Aug 12 = 30.00; 45.00/15 = 3
-- expect: 2012-08-17,3 | window Aug 03 - Aug 17: Aug 03 = 15.00, Aug 12 = 30.00; 45.00/15 = 3
-- expect: 2012-08-18,2 | window Aug 04 - Aug 18: Aug 12 = 30.00; 30.00/15 = 2
-- expect: 2012-08-19,2 | window Aug 05 - Aug 19: Aug 12 = 30.00; 30.00/15 = 2
-- expect: 2012-08-20,5 | window Aug 06 - Aug 20: Aug 12 = 30.00, Aug 20 = 45.00; 75.00/15 = 5
-- expect: 2012-08-21,5 | window Aug 07 - Aug 21: Aug 12 = 30.00, Aug 20 = 45.00; 75.00/15 = 5
-- expect: 2012-08-22,5 | window Aug 08 - Aug 22: Aug 12 = 30.00, Aug 20 = 45.00; 75.00/15 = 5
-- expect: 2012-08-23,5 | window Aug 09 - Aug 23: Aug 12 = 30.00, Aug 20 = 45.00; 75.00/15 = 5
-- expect: 2012-08-24,5 | window Aug 10 - Aug 24: Aug 12 = 30.00, Aug 20 = 45.00; 75.00/15 = 5
-- expect: 2012-08-25,5 | window Aug 11 - Aug 25: Aug 12 = 30.00, Aug 20 = 45.00; 75.00/15 = 5
-- expect: 2012-08-26,5 | window Aug 12 - Aug 26: Aug 12 = 30.00, Aug 20 = 45.00; 75.00/15 = 5
-- expect: 2012-08-27,3 | window Aug 13 - Aug 27: Aug 20 = 45.00; 45.00/15 = 3
-- expect: 2012-08-28,3 | window Aug 14 - Aug 28: Aug 20 = 45.00; 45.00/15 = 3
-- expect: 2012-08-29,3 | window Aug 15 - Aug 29: Aug 20 = 45.00; 45.00/15 = 3
-- expect: 2012-08-30,3 | window Aug 16 - Aug 30: Aug 20 = 45.00; 45.00/15 = 3
-- expect: 2012-08-31,3 | window Aug 17 - Aug 31: Aug 20 = 45.00; 45.00/15 = 3
