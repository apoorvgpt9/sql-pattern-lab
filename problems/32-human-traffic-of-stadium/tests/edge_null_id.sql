-- A NULL id. The run is defined on consecutive id values, and NULL is not a value that can follow or
-- precede anything, so busy rows with a NULL id never belong to a run - however many there are.
-- (Trap: id - ROW_NUMBER() is NULL for all of them, and PARTITION BY puts all NULLs in one partition,
-- so three NULL-id busy days look like an island of size 3.)
INSERT INTO Stadium (id, visit_date, people) VALUES
  (NULL, '2024-10-01', 200),
  (NULL, '2024-10-02', 210),
  (NULL, '2024-10-03', 220),
  (1,    '2024-10-04', 150),
  (2,    '2024-10-05', 160),
  (3,    '2024-10-06', 170),
  (5,    '2024-10-07', 180),
  (6,    '2024-10-08', 190);

-- expect: 1,2024-10-04,150 | ids 1-2-3 are consecutive and all >= 100: a run of 3
-- expect: 2,2024-10-05,160 | same run
-- expect: 3,2024-10-06,170 | same run; ids 5-6 are a run of only 2, and the three NULL-id rows have no id to be consecutive on
