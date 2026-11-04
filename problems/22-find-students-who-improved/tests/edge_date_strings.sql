-- Chronology across a year end, across month 9 -> 10, and across a leap day, rows inserted out of order.
-- 20: 2023-12-31 (30) then 2024-01-01 (40): improved. 21: 2024-09-30 (70) then 2024-10-01 (65): declined.
-- 22: 2024-02-29 (10) then 2024-03-01 (20): improved.
INSERT INTO Scores (student_id, subject, score, exam_date) VALUES
  (20, 'Math', 40, '2024-01-01'),
  (21, 'Math', 65, '2024-10-01'),
  (22, 'Math', 20, '2024-03-01'),
  (20, 'Math', 30, '2023-12-31'),
  (21, 'Math', 70, '2024-09-30'),
  (22, 'Math', 10, '2024-02-29');

-- expect: 20,Math,30,40 | the earlier year is the first exam although it was inserted second
-- expect: 22,Math,10,20 | the leap day precedes March 1
-- (21/Math: 70 on 09-30, 65 on 10-01 - declined.)
