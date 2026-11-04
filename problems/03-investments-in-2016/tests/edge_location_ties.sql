-- "Unique (lat, lon) pair": the pair must be unique, not each coordinate, and ALL members of a duplicated
-- pair are out (not just the second one).
INSERT INTO Insurance (pid, tiv_2015, tiv_2016, lat, lon) VALUES
  (1, 50.0, 11.0, 5.0, 5.0),
  (2, 50.0, 12.0, 5.0, 5.0),
  (3, 50.0, 13.0, 5.0, 6.0),
  (4, 60.0, 14.0, 7.0, 5.0),
  (5, 60.0, 15.0, 8.0, 8.0);

-- expect: 42.00 | = 13 (pid 3) + 14 (pid 4) + 15 (pid 5)
--   pids 1, 2 share the pair (5,5): both are out, including the first one
--   pid 3: lat 5 is shared with pids 1, 2 and lon is unique, but the PAIR (5,6) is unique -> counts (tiv 50 shared)
--   pid 4: lon 5 is shared with pids 1, 2, but the pair (7,5) is unique -> counts (tiv 60 shared with pid 5)
--   pid 5: pair (8,8) unique, tiv 60 shared with pid 4 -> counts
