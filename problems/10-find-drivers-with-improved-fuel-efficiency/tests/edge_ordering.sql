-- Ordering: improvement DESC on the DISPLAYED (rounded) value, then driver_name ASC.
-- Zoe (id 1) and Abe (id 2) tie exactly: the name decides, not the id.
-- Beth and Cal both display 1.00 although their unrounded improvements differ (1.001 vs 1.004): the name decides.
INSERT INTO drivers (driver_id, driver_name) VALUES (1, 'Zoe'), (2, 'Abe'), (3, 'Mia'), (4, 'Cal'), (5, 'Beth');

INSERT INTO trips (trip_id, driver_id, trip_date, distance_km, fuel_consumed) VALUES
  ( 1, 1, '2023-02-01', 40.00, 10.00), ( 2, 1, '2023-08-01', 60.00, 10.00),  -- Zoe: 4 -> 6
  ( 3, 2, '2023-02-01', 70.00, 10.00), ( 4, 2, '2023-08-01', 90.00, 10.00),  -- Abe: 7 -> 9
  ( 5, 3, '2023-02-01', 10.00, 10.00), ( 6, 3, '2023-08-01', 60.00, 10.00),  -- Mia: 1 -> 6
  ( 7, 4, '2023-02-01', 50.00, 10.00), ( 8, 4, '2023-08-01', 60.04, 10.00),  -- Cal: 5 -> 6.004
  ( 9, 5, '2023-02-01', 50.00, 10.00), (10, 5, '2023-08-01', 60.01, 10.00);  -- Beth: 5 -> 6.001

-- expect: 3,Mia,1.00,6.00,5.00 | largest improvement (5) sorts first
-- expect: 2,Abe,7.00,9.00,2.00 | improvement 2.00, ties with Zoe; 'Abe' < 'Zoe' although id 2 > id 1
-- expect: 1,Zoe,4.00,6.00,2.00 | improvement 2.00, loses the name tie-break to Abe
-- expect: 5,Beth,5.00,6.00,1.00 | 6.001 - 5 = 1.001 -> 1.00; ties with Cal on the displayed value; 'Beth' < 'Cal'
-- expect: 4,Cal,5.00,6.00,1.00 | 6.004 - 5 = 1.004 -> 1.00; sorting on the unrounded value would put Cal before Beth
