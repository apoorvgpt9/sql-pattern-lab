-- Rounding order. The improvement must be (unrounded second avg) - (unrounded first avg), rounded once.
-- Each trip is one per half so the averages equal the trip ratios. All arithmetic follows MySQL DECIMAL rules:
-- ratio scale = 2 + 4 = 6 decimals (rounded half up at the 6th), AVG keeps those digits.
INSERT INTO drivers (driver_id, driver_name) VALUES (1, 'Gus'), (2, 'Hana'), (3, 'Ira');

INSERT INTO trips (trip_id, driver_id, trip_date, distance_km, fuel_consumed) VALUES
  (1, 1, '2023-01-10', 112.36, 10.00),  -- 112.36 / 10.00 = 11.236000
  (2, 1, '2023-10-10', 133.34, 10.00),  -- 133.34 / 10.00 = 13.334000
  (3, 2, '2023-02-10',  10.00,  3.00),  -- 10 / 3 = 3.333333 (6 decimals)
  (4, 2, '2023-11-10',  20.00,  3.00),  -- 20 / 3 = 6.666667 (6 decimals, last digit rounded up)
  (5, 3, '2023-03-10',  50.01, 10.00),  -- 5.001000
  (6, 3, '2023-12-10',  50.04, 10.00);  -- 5.004000

-- expect: 2,Hana,3.33,6.67,3.33 | first 3.333333 -> 3.33; second 6.666667 -> 6.67; diff 6.666667 - 3.333333 = 3.333334 -> 3.33 (rounding first would give 6.67 - 3.33 = 3.34)
-- expect: 1,Gus,11.24,13.33,2.10 | first 11.236 -> 11.24; second 13.334 -> 13.33; diff 13.334 - 11.236 = 2.098 -> 2.10 (rounding first would give 13.33 - 11.24 = 2.09)
-- expect: 3,Ira,5.00,5.00,0.00 | second 5.004 > first 5.001 on unrounded values, so she qualifies; every number displays as 5.00 / 5.00 / 0.00 (a filter on rounded values would drop her)
