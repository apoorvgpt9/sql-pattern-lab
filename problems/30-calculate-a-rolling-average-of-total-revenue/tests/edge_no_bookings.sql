-- No bookings at all. The result is still 31 rows (one per August date), every revenue 0.
INSERT INTO facilities (facid, name, membercost, guestcost, initialoutlay, monthlymaintenance) VALUES
  (2, 'Cue Room', 0.00, 5.00, 400, 15);


-- expect: 2012-08-01,0 | window Jul 18 - Aug 01: no bookings; 0/15 = 0
-- expect: 2012-08-02,0 | window Jul 19 - Aug 02: no bookings; 0/15 = 0
-- expect: 2012-08-03,0 | window Jul 20 - Aug 03: no bookings; 0/15 = 0
-- expect: 2012-08-04,0 | window Jul 21 - Aug 04: no bookings; 0/15 = 0
-- expect: 2012-08-05,0 | window Jul 22 - Aug 05: no bookings; 0/15 = 0
-- expect: 2012-08-06,0 | window Jul 23 - Aug 06: no bookings; 0/15 = 0
-- expect: 2012-08-07,0 | window Jul 24 - Aug 07: no bookings; 0/15 = 0
-- expect: 2012-08-08,0 | window Jul 25 - Aug 08: no bookings; 0/15 = 0
-- expect: 2012-08-09,0 | window Jul 26 - Aug 09: no bookings; 0/15 = 0
-- expect: 2012-08-10,0 | window Jul 27 - Aug 10: no bookings; 0/15 = 0
-- expect: 2012-08-11,0 | window Jul 28 - Aug 11: no bookings; 0/15 = 0
-- expect: 2012-08-12,0 | window Jul 29 - Aug 12: no bookings; 0/15 = 0
-- expect: 2012-08-13,0 | window Jul 30 - Aug 13: no bookings; 0/15 = 0
-- expect: 2012-08-14,0 | window Jul 31 - Aug 14: no bookings; 0/15 = 0
-- expect: 2012-08-15,0 | window Aug 01 - Aug 15: no bookings; 0/15 = 0
-- expect: 2012-08-16,0 | window Aug 02 - Aug 16: no bookings; 0/15 = 0
-- expect: 2012-08-17,0 | window Aug 03 - Aug 17: no bookings; 0/15 = 0
-- expect: 2012-08-18,0 | window Aug 04 - Aug 18: no bookings; 0/15 = 0
-- expect: 2012-08-19,0 | window Aug 05 - Aug 19: no bookings; 0/15 = 0
-- expect: 2012-08-20,0 | window Aug 06 - Aug 20: no bookings; 0/15 = 0
-- expect: 2012-08-21,0 | window Aug 07 - Aug 21: no bookings; 0/15 = 0
-- expect: 2012-08-22,0 | window Aug 08 - Aug 22: no bookings; 0/15 = 0
-- expect: 2012-08-23,0 | window Aug 09 - Aug 23: no bookings; 0/15 = 0
-- expect: 2012-08-24,0 | window Aug 10 - Aug 24: no bookings; 0/15 = 0
-- expect: 2012-08-25,0 | window Aug 11 - Aug 25: no bookings; 0/15 = 0
-- expect: 2012-08-26,0 | window Aug 12 - Aug 26: no bookings; 0/15 = 0
-- expect: 2012-08-27,0 | window Aug 13 - Aug 27: no bookings; 0/15 = 0
-- expect: 2012-08-28,0 | window Aug 14 - Aug 28: no bookings; 0/15 = 0
-- expect: 2012-08-29,0 | window Aug 15 - Aug 29: no bookings; 0/15 = 0
-- expect: 2012-08-30,0 | window Aug 16 - Aug 30: no bookings; 0/15 = 0
-- expect: 2012-08-31,0 | window Aug 17 - Aug 31: no bookings; 0/15 = 0
