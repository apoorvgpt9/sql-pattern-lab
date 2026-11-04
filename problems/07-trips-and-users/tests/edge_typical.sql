-- Users 2 (client) and 11 (driver) are banned. Three in-range days plus one day on each side of the range.
INSERT INTO Users (users_id, banned, role) VALUES
  (1,  'No',  'client'),
  (2,  'Yes', 'client'),
  (3,  'No',  'client'),
  (4,  'No',  'client'),
  (10, 'No',  'driver'),
  (11, 'Yes', 'driver'),
  (12, 'No',  'driver'),
  (13, 'No',  'driver');

INSERT INTO Trips (id, client_id, driver_id, city_id, status, request_at) VALUES
  (1,  1, 10, 1, 'completed',           '2013-10-01'),
  (2,  2, 10, 1, 'cancelled_by_driver', '2013-10-01'),
  (3,  1, 11, 1, 'cancelled_by_client', '2013-10-01'),
  (4,  3, 12, 1, 'cancelled_by_client', '2013-10-01'),
  (5,  3, 13, 1, 'completed',           '2013-10-01'),
  (6,  1, 12, 1, 'cancelled_by_driver', '2013-10-02'),
  (7,  4, 13, 1, 'cancelled_by_client', '2013-10-02'),
  (8,  3, 10, 1, 'completed',           '2013-10-02'),
  (9,  4, 12, 1, 'completed',           '2013-10-02'),
  (10, 1, 10, 1, 'completed',           '2013-10-03'),
  (11, 3, 13, 1, 'completed',           '2013-10-03'),
  (12, 2, 11, 1, 'cancelled_by_driver', '2013-10-03'),
  (13, 1, 10, 1, 'cancelled_by_client', '2013-10-04'),
  (14, 1, 10, 1, 'completed',           '2013-09-30');

-- expect: 2013-10-01,0.33 | trips 1,4,5 are eligible (2 and 3 involve a banned client / driver); 1 cancelled of 3 = 0.3333 -> 0.33
-- expect: 2013-10-02,0.50 | trips 6,7,8,9 all eligible; cancelled by driver (6) and by client (7) both count: 2 of 4 = 0.50
-- expect: 2013-10-03,0.00 | trips 10,11 eligible, both completed: 0 of 2 -> 0.00 (a day with no cancellations still appears); trip 12 has two banned users
--   trips 13 (2013-10-04) and 14 (2013-09-30) are outside the date range
