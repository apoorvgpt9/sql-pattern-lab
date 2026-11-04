-- Boundary of the people filter: exactly 100 counts (>= 100), 99 does not.
INSERT INTO Stadium (id, visit_date, people) VALUES
  (1, '2024-01-01', 100),
  (2, '2024-01-02', 100),
  (3, '2024-01-03', 100),
  (4, '2024-01-04',  99),   -- one short: breaks the run
  (5, '2024-01-05', 101),
  (6, '2024-01-06', 101);   -- run 5-6 has length 2

-- expect: 1,2024-01-01,100 | 100 >= 100; ids 1-3 form a run of exactly 3
-- expect: 2,2024-01-02,100 | same run
-- expect: 3,2024-01-03,100 | same run; id 4 (99) ends it
