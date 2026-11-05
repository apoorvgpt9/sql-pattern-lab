-- ids start at 0. The spec defines runs on consecutive id values and never says ids start at 1.
-- (Trap: ROW_NUMBER() is BIGINT UNSIGNED in MySQL, so id - ROW_NUMBER() is unsigned arithmetic and
-- 0 - 1 raises "BIGINT UNSIGNED value is out of range" instead of returning -1.)
INSERT INTO Stadium (id, visit_date, people) VALUES
  (0, '2024-11-01', 100),
  (1, '2024-11-02', 101),
  (2, '2024-11-03', 102),
  (3, '2024-11-04',  99),
  (4, '2024-11-05', 300),
  (5, '2024-11-06', 400);

-- expect: 0,2024-11-01,100 | ids 0-1-2 are consecutive and all >= 100 (100 counts): a run of 3
-- expect: 1,2024-11-02,101 | same run
-- expect: 2,2024-11-03,102 | same run; id 3 has 99 < 100, so ids 4-5 are only a run of 2
