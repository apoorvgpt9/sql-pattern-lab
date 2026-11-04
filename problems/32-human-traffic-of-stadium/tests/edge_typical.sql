-- Typical: three runs of busy days (people >= 100): ids 2-3 (length 2), 5-8 (length 4), 10-11 (length 2).
-- Only the length-4 run qualifies, and all four of its rows must come back - including the
-- middle ones (6, 7) and the last ones (7, 8), which "starts a run of 3" logic misses.
INSERT INTO Stadium (id, visit_date, people) VALUES
  (1,  '2024-03-01',  12),
  (2,  '2024-03-02', 140),
  (3,  '2024-03-03', 160),
  (4,  '2024-03-04',  99),   -- 99 < 100: breaks the run 2-3 off at length 2
  (5,  '2024-03-05', 210),
  (6,  '2024-03-06', 130),
  (7,  '2024-03-07', 175),
  (8,  '2024-03-08', 400),
  (9,  '2024-03-09',  50),
  (10, '2024-03-10', 300),
  (11, '2024-03-11', 220);   -- run 10-11 ends with the table at length 2

-- expect: 5,2024-03-05,210 | first row of the busy run 5-8 (length 4 >= 3)
-- expect: 6,2024-03-06,130 | inside run 5-8
-- expect: 7,2024-03-07,175 | inside run 5-8
-- expect: 8,2024-03-08,400 | last row of run 5-8; id 9 has 50 people
