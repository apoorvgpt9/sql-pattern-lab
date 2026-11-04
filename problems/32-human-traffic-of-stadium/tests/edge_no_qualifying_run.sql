-- Plenty of busy days, but never three consecutive ids in a row: every run has length 1 or 2.
INSERT INTO Stadium (id, visit_date, people) VALUES
  (1, '2024-07-01', 500),
  (2, '2024-07-02', 500),
  (3, '2024-07-03',  10),
  (4, '2024-07-04', 500),
  (5, '2024-07-05',  10),
  (6, '2024-07-06', 500),
  (7, '2024-07-07', 500);

-- expect-empty: runs are 1-2 (length 2), 4 (length 1) and 6-7 (length 2); none reaches 3
