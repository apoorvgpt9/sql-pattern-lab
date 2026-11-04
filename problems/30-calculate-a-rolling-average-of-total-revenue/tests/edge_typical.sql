-- Typical: bookings before the first window, in July (inside the Aug 1-3 windows), in August, on the last August
-- day at 23:30, and on 2012-09-01 (outside August, never in an August window). Two facilities have a member price of 0
-- or a different member price; guests (memid 0) pay guestcost, members pay membercost.
-- Revenue per booking = slots * cost: 10, 100, 70, 30, 0, 240, 5, 50. Window = the date and the 14 days before it;
-- days without bookings count as 0, so every window is divided by 15. MySQL: DECIMAL(10,2) total / 15 keeps 6 decimals.
INSERT INTO facilities (facid, name, membercost, guestcost, initialoutlay, monthlymaintenance) VALUES
  (0, 'Court A', 5.00, 25.00, 9000, 200),
  (1, 'Spa Suite', 35.00, 80.00, 4000, 3000),
  (2, 'Cue Room', 0.00, 5.00, 400, 15);

INSERT INTO bookings (bookid, facid, memid, starttime, slots) VALUES
  (1, 0, 3, '2012-07-10 10:00:00', 2),
  (2, 0, 0, '2012-07-20 09:00:00', 4),
  (3, 1, 5, '2012-07-20 15:00:00', 2),
  (4, 2, 0, '2012-08-05 10:00:00', 6),
  (5, 2, 7, '2012-08-05 11:00:00', 4),
  (6, 1, 0, '2012-08-15 12:00:00', 3),
  (7, 0, 2, '2012-08-31 23:30:00', 1),
  (8, 0, 0, '2012-09-01 00:00:00', 2);

INSERT INTO members (memid, surname, firstname, address, zipcode, telephone, recommendedby, joindate) VALUES
  (0, 'GUEST', 'GUEST', 'GUEST', 0, '000-0000', NULL, '2012-01-01 00:00:00'),
  (2, 'Okafor', 'Ife', '1 Mill Lane', 10001, '555-0102', NULL, '2012-02-01 09:00:00'),
  (3, 'Lindqvist', 'Mats', '2 Quay Road', 10002, '555-0103', 2, '2012-02-02 09:00:00'),
  (5, 'Haddad', 'Rima', '3 Hill Street', 10003, '555-0105', 2, '2012-02-03 09:00:00'),
  (7, 'Costa', 'Ines', '4 Park Avenue', 10004, '555-0107', 3, '2012-02-04 09:00:00');

-- expect: 2012-08-01,11.333333 | window Jul 18 - Aug 01: Jul 20 = 170.00; 170.00/15 = 11.333333
-- expect: 2012-08-02,11.333333 | window Jul 19 - Aug 02: Jul 20 = 170.00; 170.00/15 = 11.333333
-- expect: 2012-08-03,11.333333 | window Jul 20 - Aug 03: Jul 20 = 170.00; 170.00/15 = 11.333333
-- expect: 2012-08-04,0 | window Jul 21 - Aug 04: no bookings; 0/15 = 0
-- expect: 2012-08-05,2 | window Jul 22 - Aug 05: Aug 05 = 30.00; 30.00/15 = 2
-- expect: 2012-08-06,2 | window Jul 23 - Aug 06: Aug 05 = 30.00; 30.00/15 = 2
-- expect: 2012-08-07,2 | window Jul 24 - Aug 07: Aug 05 = 30.00; 30.00/15 = 2
-- expect: 2012-08-08,2 | window Jul 25 - Aug 08: Aug 05 = 30.00; 30.00/15 = 2
-- expect: 2012-08-09,2 | window Jul 26 - Aug 09: Aug 05 = 30.00; 30.00/15 = 2
-- expect: 2012-08-10,2 | window Jul 27 - Aug 10: Aug 05 = 30.00; 30.00/15 = 2
-- expect: 2012-08-11,2 | window Jul 28 - Aug 11: Aug 05 = 30.00; 30.00/15 = 2
-- expect: 2012-08-12,2 | window Jul 29 - Aug 12: Aug 05 = 30.00; 30.00/15 = 2
-- expect: 2012-08-13,2 | window Jul 30 - Aug 13: Aug 05 = 30.00; 30.00/15 = 2
-- expect: 2012-08-14,2 | window Jul 31 - Aug 14: Aug 05 = 30.00; 30.00/15 = 2
-- expect: 2012-08-15,18 | window Aug 01 - Aug 15: Aug 05 = 30.00, Aug 15 = 240.00; 270.00/15 = 18
-- expect: 2012-08-16,18 | window Aug 02 - Aug 16: Aug 05 = 30.00, Aug 15 = 240.00; 270.00/15 = 18
-- expect: 2012-08-17,18 | window Aug 03 - Aug 17: Aug 05 = 30.00, Aug 15 = 240.00; 270.00/15 = 18
-- expect: 2012-08-18,18 | window Aug 04 - Aug 18: Aug 05 = 30.00, Aug 15 = 240.00; 270.00/15 = 18
-- expect: 2012-08-19,18 | window Aug 05 - Aug 19: Aug 05 = 30.00, Aug 15 = 240.00; 270.00/15 = 18
-- expect: 2012-08-20,16 | window Aug 06 - Aug 20: Aug 15 = 240.00; 240.00/15 = 16
-- expect: 2012-08-21,16 | window Aug 07 - Aug 21: Aug 15 = 240.00; 240.00/15 = 16
-- expect: 2012-08-22,16 | window Aug 08 - Aug 22: Aug 15 = 240.00; 240.00/15 = 16
-- expect: 2012-08-23,16 | window Aug 09 - Aug 23: Aug 15 = 240.00; 240.00/15 = 16
-- expect: 2012-08-24,16 | window Aug 10 - Aug 24: Aug 15 = 240.00; 240.00/15 = 16
-- expect: 2012-08-25,16 | window Aug 11 - Aug 25: Aug 15 = 240.00; 240.00/15 = 16
-- expect: 2012-08-26,16 | window Aug 12 - Aug 26: Aug 15 = 240.00; 240.00/15 = 16
-- expect: 2012-08-27,16 | window Aug 13 - Aug 27: Aug 15 = 240.00; 240.00/15 = 16
-- expect: 2012-08-28,16 | window Aug 14 - Aug 28: Aug 15 = 240.00; 240.00/15 = 16
-- expect: 2012-08-29,16 | window Aug 15 - Aug 29: Aug 15 = 240.00; 240.00/15 = 16
-- expect: 2012-08-30,0 | window Aug 16 - Aug 30: no bookings; 0/15 = 0
-- expect: 2012-08-31,0.333333 | window Aug 17 - Aug 31: Aug 31 = 5.00; 5.00/15 = 0.333333
