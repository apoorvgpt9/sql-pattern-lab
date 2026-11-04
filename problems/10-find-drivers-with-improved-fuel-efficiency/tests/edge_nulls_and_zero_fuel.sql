-- Trips whose efficiency is undefined: NULL distance, NULL fuel, zero fuel, and a NULL date.
-- Assumption (README): such trips are ignored, they neither count as a trip in a half nor as efficiency 0.
-- (MySQL SELECT returns NULL, not an error, for x / 0, but Snowflake raises an error: solutions use NULLIF(fuel, 0).)
INSERT INTO drivers (driver_id, driver_name) VALUES (1, 'Oro'), (2, 'Pia'), (3, 'Quin');

INSERT INTO trips (trip_id, driver_id, trip_date, distance_km, fuel_consumed) VALUES
  (1, 1, '2023-01-10',  60.00, 10.00),  -- Oro first half: 6
  (2, 1, '2023-02-10',  NULL,  10.00),  -- NULL distance: no efficiency, ignored
  (3, 1, '2023-08-10',  80.00, 10.00),  -- Oro second half: 8
  (4, 1, '2023-09-10',  50.00,  0.00),  -- zero fuel: no efficiency, ignored
  (5, 1, NULL,        1000.00, 10.00),  -- NULL date: in neither half (ratio 100 would wreck the averages)
  (6, 2, '2023-03-10',  40.00, 10.00),  -- Pia first half: 4
  (7, 2, '2023-10-10',  30.00,  0.00),  -- Pia second half: zero fuel
  (8, 2, '2023-11-10',  30.00,  NULL),  -- Pia second half: NULL fuel
  (9, 3, '2023-03-10',  30.00,  0.00),  -- Quin first half: zero fuel
  (10, 3, '2023-10-10', 70.00, 10.00);  -- Quin second half: 7

-- expect: 1,Oro,6.00,8.00,2.00 | first = 6 (the NULL-distance trip is ignored); second = 8 (zero-fuel trip ignored); the NULL-date trip is in neither half
-- (Pia has no valid second-half trip and Quin no valid first-half trip, so neither has two half averages)
