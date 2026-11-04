-- The range is inclusive at both ends: 2013-10-01 and 2013-10-03 are in, 2013-09-30 and 2013-10-04 are out.
INSERT INTO Users (users_id, banned, role) VALUES
  (1,  'No', 'client'),
  (10, 'No', 'driver');

INSERT INTO Trips (id, client_id, driver_id, city_id, status, request_at) VALUES
  (1, 1, 10, 1, 'cancelled_by_client', '2013-09-30'),
  (2, 1, 10, 1, 'completed',           '2013-10-01'),
  (3, 1, 10, 1, 'cancelled_by_driver', '2013-10-03'),
  (4, 1, 10, 1, 'completed',           '2013-10-03'),
  (5, 1, 10, 1, 'cancelled_by_client', '2013-10-04');

-- expect: 2013-10-01,0.00 | the first day of the range is included: 1 trip, completed
-- expect: 2013-10-03,0.50 | the last day of the range is included: 1 of 2 cancelled
--   2013-09-30 and 2013-10-04 are one day outside the range and are not reported
