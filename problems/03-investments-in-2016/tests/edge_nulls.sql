-- NULL tiv_2015 never "equals" anything, so two NULLs are not a shared value (SQL equality). A NULL
-- tiv_2016 is skipped by SUM.
INSERT INTO Insurance (pid, tiv_2015, tiv_2016, lat, lon) VALUES
  (1, NULL, 5.0,  1.0, 1.0),
  (2, NULL, 6.0,  2.0, 2.0),
  (3, 10.0, NULL, 3.0, 3.0),
  (4, 10.0, 7.0,  4.0, 4.0);

-- expect: 7.00 | pids 3 and 4 share tiv 10 and have unique locations; pid 3's NULL tiv_2016 adds nothing, pid 4 adds 7
--   pids 1 and 2 have tiv_2015 NULL: NULL = NULL is not true, so they do not share a value (assumption, see README) -> out
