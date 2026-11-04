-- Index recommended in README "At scale" (b). The bench runs every solution without it, then with it.
-- (driver_id, trip_date, distance_km, fuel_consumed) is covering: every approach reads exactly these
-- columns of trips. Approach 1's per-driver subqueries become index range reads of one driver's entries,
-- and approaches 2 and 3 can group in driver_id order without a temporary table.
CREATE INDEX idx_trips_driver_cover ON trips (driver_id, trip_date, distance_km, fuel_consumed);
