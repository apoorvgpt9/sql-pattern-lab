-- Three exams each, where the best/worst score is in the MIDDLE. Only the first and the latest exam count.
-- 10: 60 -> 95 -> 55: a peak in between, but the latest (55) is below the first (60): not improved.
-- 11: 60 -> 40 -> 70: a dip in between, the latest (70) is above the first (60): improved.
-- 12: 50 -> 90 -> 60: a peak in between, the latest (60) is above the first (50): improved (not 50 -> 90).
INSERT INTO Scores (student_id, subject, score, exam_date) VALUES
  (10, 'Math', 60, '2024-01-01'),
  (10, 'Math', 95, '2024-02-01'),
  (10, 'Math', 55, '2024-03-01'),
  (11, 'Math', 40, '2024-02-01'),
  (11, 'Math', 70, '2024-03-01'),
  (11, 'Math', 60, '2024-01-01'),
  (12, 'Math', 90, '2024-02-01'),
  (12, 'Math', 60, '2024-03-01'),
  (12, 'Math', 50, '2024-01-01');

-- expect: 11,Math,60,70 | first 60 (Jan), latest 70 (Mar): improved although the middle exam (40) was lower than both
-- expect: 12,Math,50,60 | first 50, latest 60: improved; the 90 in February is neither first nor latest
-- (10/Math: first 60, latest 55 - declined, even though 60 -> 95 improved between the first two exams.)
