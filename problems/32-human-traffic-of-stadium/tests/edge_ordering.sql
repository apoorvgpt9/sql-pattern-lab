-- Output order: rows are inserted in scrambled order; the result must be sorted by visit_date.
-- Two qualifying runs, one at each end of the table (no row before id 1, none after id 9),
-- which is where LAG/LEAD return NULL.
INSERT INTO Stadium (id, visit_date, people) VALUES
  (7, '2024-11-07', 170),
  (2, '2024-11-02', 120),
  (9, '2024-11-09', 190),
  (4, '2024-11-04',  40),   -- the only quiet day
  (1, '2024-11-01', 110),
  (6, '2024-11-06', 160),
  (3, '2024-11-03', 130),
  (8, '2024-11-08', 180),
  (5, '2024-11-05', 150);

-- expect: 1,2024-11-01,110 | run 1-3 (length 3) starts at the first row of the table
-- expect: 2,2024-11-02,120 | run 1-3
-- expect: 3,2024-11-03,130 | run 1-3; id 4 has 40 people
-- expect: 5,2024-11-05,150 | run 5-9 (length 5)
-- expect: 6,2024-11-06,160 | run 5-9
-- expect: 7,2024-11-07,170 | run 5-9
-- expect: 8,2024-11-08,180 | run 5-9
-- expect: 9,2024-11-09,190 | run 5-9 ends at the last row of the table
