-- A NULL people count. NULL >= 100 is unknown, so the row is not a busy day and it breaks the run.
INSERT INTO Stadium (id, visit_date, people) VALUES
  (1, '2024-09-01',  120),
  (2, '2024-09-02', NULL),  -- unknown attendance: not >= 100, splits 1 from 3-5
  (3, '2024-09-03',  130),
  (4, '2024-09-04',  140),
  (5, '2024-09-05',  150);

-- expect: 3,2024-09-03,130 | run 3-5 has length 3
-- expect: 4,2024-09-04,140 | same run
-- expect: 5,2024-09-05,150 | same run; id 1 is a run of 1 because id 2 is NULL
