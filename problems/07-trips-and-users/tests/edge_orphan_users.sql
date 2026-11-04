-- Trips whose client (99) or driver (98) is not in Users. A trip counts only when BOTH users exist and are unbanned
-- (assumption in the README: the spec guarantees the foreign key, so this case is outside the spec; this is the choice).
INSERT INTO Users (users_id, banned, role) VALUES
  (1,  'No', 'client'),
  (10, 'No', 'driver');

INSERT INTO Trips (id, client_id, driver_id, city_id, status, request_at) VALUES
  (1, 1,  10, 1, 'completed',           '2013-10-01'),
  (2, 99, 10, 1, 'cancelled_by_client', '2013-10-01'),
  (3, 1,  98, 1, 'cancelled_by_driver', '2013-10-01');

-- expect: 2013-10-01,0.00 | only trip 1 has two existing, unbanned users, and it is completed; trips 2 and 3 reference unknown users and are not counted
