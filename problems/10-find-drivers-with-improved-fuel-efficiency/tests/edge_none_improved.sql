-- Nobody improved: a decline, an exact tie, and a driver with only second-half trips. The result is empty.
INSERT INTO drivers (driver_id, driver_name) VALUES (1, 'Lia'), (2, 'Max'), (3, 'Noe');

INSERT INTO trips (trip_id, driver_id, trip_date, distance_km, fuel_consumed) VALUES
  (1, 1, '2023-02-01', 100.00, 10.00),  -- Lia first half: 10
  (2, 1, '2023-08-01',  80.00, 10.00),  -- Lia second half: 8 (worse)
  (3, 2, '2023-02-01',  60.00, 10.00),  -- Max first half: 6
  (4, 2, '2023-08-01',  60.00, 10.00),  -- Max second half: 6 (equal: not an improvement)
  (5, 3, '2023-09-01',  90.00, 10.00);  -- Noe: second half only, no first half to improve on

-- expect-empty: Lia declined (10 -> 8), Max stayed flat (6 -> 6), Noe has no first-half trips
