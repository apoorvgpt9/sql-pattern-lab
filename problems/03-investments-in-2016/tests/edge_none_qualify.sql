-- Rows exist but none satisfies both conditions.
INSERT INTO Insurance (pid, tiv_2015, tiv_2016, lat, lon) VALUES
  (1, 10.0, 5.0, 1.0, 1.0),
  (2, 20.0, 6.0, 2.0, 2.0),
  (3, 20.0, 7.0, 2.0, 2.0);

-- expect: NULL | still exactly one row: SUM over zero qualifying rows is NULL, not 0
--   (pid 1: tiv 10 is unique; pids 2 and 3 share tiv 20 but also share location (2,2))
