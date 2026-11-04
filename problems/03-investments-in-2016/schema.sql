-- Investments in 2016: tables for MySQL 8.0. Names mirror the original.
-- lat and lon are NOT NULL (guaranteed by the spec). tiv_2015 and tiv_2016 are left nullable on
-- purpose: the spec does not forbid NULL there, so edge_nulls pins down what we assume (see README).

CREATE TABLE Insurance (
  pid      INT PRIMARY KEY,   -- grain: one row per policy
  tiv_2015 FLOAT,
  tiv_2016 FLOAT,
  lat      FLOAT NOT NULL,
  lon      FLOAT NOT NULL
);
