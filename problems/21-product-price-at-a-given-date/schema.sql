-- Product Price at a Given Date: tables for MySQL 8.0. Names mirror the original.
-- DRAFT generated from problems.yaml: check every type and nullability, then uncomment.
-- The harness runs this in a fresh, empty database: no CREATE DATABASE / USE here.

-- grain: PK (product_id, change_date); one row per price change
-- CREATE TABLE Products (
--   product_id INT,
--   new_price INT,
--   change_date DATE
-- );
