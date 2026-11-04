-- Seven policies. Values are multiples of 0.25 so FLOAT stores them exactly.
INSERT INTO Insurance (pid, tiv_2015, tiv_2016, lat, lon) VALUES
  (1, 100.0, 110.5, 1.0, 1.0),
  (2, 100.0,  90.25, 2.0, 2.0),
  (3, 100.0,  40.0, 3.0, 3.0),
  (4, 200.0,  70.0, 4.0, 4.0),
  (5, 300.0,  15.5, 2.0, 2.0),
  (6, 400.0,   8.75, 6.0, 6.0),
  (7, 400.0,   3.0, 7.0, 7.0);

-- expect: 162.25 | = 110.5 (pid 1) + 40.0 (pid 3) + 8.75 (pid 6) + 3.0 (pid 7)
--   pid 1: tiv 100 shared with pids 2,3; (1,1) is unique        -> counts
--   pid 2: tiv shared, but (2,2) is also pid 5's location         -> out
--   pid 3: tiv 100 shared; (3,3) unique                           -> counts
--   pid 4: (4,4) unique but tiv 200 is nobody else's              -> out
--   pid 5: tiv 300 unique and (2,2) shared                        -> out
--   pids 6, 7: tiv 400 shared with each other; locations unique   -> count
