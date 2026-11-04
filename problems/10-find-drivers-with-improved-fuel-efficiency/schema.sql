-- Find Drivers with Improved Fuel Efficiency (LeetCode 3601): tables for MySQL 8.0. Names mirror the original.
-- No foreign key, as on LeetCode: trips may reference a driver_id that is not in drivers.
-- distance_km / fuel_consumed are nullable here on purpose: see README "Assumptions".
-- MySQL arithmetic note: DECIMAL(10,2) / DECIMAL(10,2) has scale 2 + div_precision_increment(4) = 6,
-- and AVG() of that adds 4 more, so "unrounded" averages carry 10 decimal places.

CREATE TABLE drivers (
  driver_id   INT PRIMARY KEY,   -- grain: one row per driver
  driver_name VARCHAR(100)
);

CREATE TABLE trips (
  trip_id       INT PRIMARY KEY,   -- grain: one row per trip
  driver_id     INT,
  trip_date     DATE,
  distance_km   DECIMAL(10,2),
  fuel_consumed DECIMAL(10,2)
);
