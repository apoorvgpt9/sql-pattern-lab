-- Half-year boundaries and the rule "month only, years are not separated".
-- January-June is the first half, July-December the second, in whichever year.
INSERT INTO drivers (driver_id, driver_name) VALUES (1, 'Ivy'), (2, 'Jon'), (3, 'Kai');

INSERT INTO trips (trip_id, driver_id, trip_date, distance_km, fuel_consumed) VALUES
  (1, 1, '2022-01-01',  50.00, 10.00),  -- Ivy: 1 Jan, first half: 5
  (2, 1, '2022-06-30',  70.00, 10.00),  -- Ivy: 30 Jun, still first half: 7
  (3, 1, '2022-07-01',  80.00, 10.00),  -- Ivy: 1 Jul, second half: 8
  (4, 1, '2022-12-31', 100.00, 10.00),  -- Ivy: 31 Dec, second half: 10
  (5, 2, '2021-03-15',  60.00, 10.00),  -- Jon: first half of 2021: 6
  (6, 2, '2023-03-15',  80.00, 10.00),  -- Jon: first half of 2023: 8 (same half as the 2021 trip: years are not separated)
  (7, 2, '2022-09-15',  90.00, 10.00),  -- Jon: second half of 2022: 9
  (8, 3, '2023-01-15',  50.00, 10.00),  -- Kai: first half: 5
  (9, 3, '2023-07-15',  50.00, 10.00);  -- Kai: second half: 5, exactly equal

-- expect: 1,Ivy,6.00,9.00,3.00 | first = AVG(5, 7) = 6 (30 Jun is first half); second = AVG(8, 10) = 9 (1 Jul is second half)
-- expect: 2,Jon,7.00,9.00,2.00 | first = AVG(6, 8) = 7 across two different years; second = 9
-- (Kai: 5 vs 5 is no improvement, so no row; "exceeds" is strict)
