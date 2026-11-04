-- Rounding: an exact half (1/8), a repeating decimal below and above a half (1/3, 2/3). MySQL divides exact numbers
-- (DECIMAL) and rounds halves away from zero.
INSERT INTO Users (users_id, banned, role) VALUES
  (1,  'No', 'client'),
  (10, 'No', 'driver');

INSERT INTO Trips (id, client_id, driver_id, city_id, status, request_at) VALUES
  (1,  1, 10, 1, 'cancelled_by_driver', '2013-10-01'),
  (2,  1, 10, 1, 'completed',           '2013-10-01'),
  (3,  1, 10, 1, 'completed',           '2013-10-01'),
  (4,  1, 10, 1, 'completed',           '2013-10-01'),
  (5,  1, 10, 1, 'completed',           '2013-10-01'),
  (6,  1, 10, 1, 'completed',           '2013-10-01'),
  (7,  1, 10, 1, 'completed',           '2013-10-01'),
  (8,  1, 10, 1, 'completed',           '2013-10-01'),
  (9,  1, 10, 1, 'cancelled_by_client', '2013-10-02'),
  (10, 1, 10, 1, 'completed',           '2013-10-02'),
  (11, 1, 10, 1, 'completed',           '2013-10-02'),
  (12, 1, 10, 1, 'cancelled_by_client', '2013-10-03'),
  (13, 1, 10, 1, 'cancelled_by_driver', '2013-10-03'),
  (14, 1, 10, 1, 'completed',           '2013-10-03');

-- expect: 2013-10-01,0.13 | 1 cancelled of 8 = 0.1250 exactly; ROUND(0.1250, 2) rounds the half up -> 0.13 (a binary double would give 0.12)
-- expect: 2013-10-02,0.33 | 1 of 3 = 0.3333 -> 0.33
-- expect: 2013-10-03,0.67 | 2 of 3 = 0.6667 -> 0.67
