-- Typical mix. Asha is built so that "average of per-trip ratios" and "total distance / total fuel" disagree.
-- Also: a driver who declined, drivers with only one half, a driver with no trips, and trips of an unknown driver.
INSERT INTO drivers (driver_id, driver_name) VALUES
  (1, 'Asha'), (2, 'Bram'), (3, 'Chen'), (4, 'Dara'), (5, 'Eli'), (6, 'Fay');

INSERT INTO trips (trip_id, driver_id, trip_date, distance_km, fuel_consumed) VALUES
  ( 1, 1, '2023-02-10', 100.00, 10.00),  -- Asha first half: 100/10 = 10
  ( 2, 1, '2023-03-10',  20.00,  4.00),  -- Asha first half: 20/4 = 5
  ( 3, 1, '2023-08-10',  90.00, 10.00),  -- Asha second half: 90/10 = 9
  ( 4, 1, '2023-09-10',  60.00,  5.00),  -- Asha second half: 60/5 = 12
  ( 5, 2, '2023-05-01', 120.00, 10.00),  -- Bram first half: 12
  ( 6, 2, '2023-12-01',  90.00, 10.00),  -- Bram second half: 9 (declined)
  ( 7, 3, '2023-01-15',  50.00, 10.00),  -- Chen: first half only
  ( 8, 4, '2023-07-15',  70.00, 10.00),  -- Dara: second half only
  ( 9, 6, '2023-04-04',  80.00, 10.00),  -- Fay first half: 8
  (10, 6, '2023-11-04',  85.00, 10.00),  -- Fay second half: 8.5
  (11, 99, '2023-03-03', 10.00,  1.00),  -- driver 99 does not exist: would "improve" 10 -> 20 but has no row to report
  (12, 99, '2023-09-09', 20.00,  1.00);

-- expect: 1,Asha,7.50,10.50,3.00 | first = AVG(10, 5) = 7.5; second = AVG(9, 12) = 10.5; difference 3.0 (ratio-of-sums would give 8.57 / 10.00 / 1.43)
-- expect: 6,Fay,8.00,8.50,0.50 | first 80/10 = 8; second 85/10 = 8.5; difference 0.5
-- (Bram declined; Chen and Dara have one half only; Eli has no trips; driver 99 has no drivers row)
