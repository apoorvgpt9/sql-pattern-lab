-- A day whose every trip involves a banned user has no eligible trips: it must NOT appear (not even as NULL or 0.00).
INSERT INTO Users (users_id, banned, role) VALUES
  (1,  'No',  'client'),
  (2,  'Yes', 'client'),
  (10, 'No',  'driver'),
  (11, 'Yes', 'driver');

INSERT INTO Trips (id, client_id, driver_id, city_id, status, request_at) VALUES
  (1, 2, 10, 1, 'cancelled_by_driver', '2013-10-01'),
  (2, 1, 11, 1, 'completed',           '2013-10-01'),
  (3, 1, 10, 1, 'cancelled_by_client', '2013-10-02');

-- expect: 2013-10-02,1.00 | the only eligible trip is cancelled: 1 of 1 = 1.00
--   2013-10-01 has trips, but one has a banned client and the other a banned driver: no eligible trip, so the day is absent
