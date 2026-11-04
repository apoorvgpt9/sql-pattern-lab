-- Tests the output ORDER: student_id ascending, then subject ascending. Every pair improves.
-- Rows are inserted in a scrambled order; student 12 sorts after student 7 numerically.
INSERT INTO Scores (student_id, subject, score, exam_date) VALUES
  (12, 'Art',       10, '2024-01-01'), (12, 'Art',       20, '2024-02-01'),
  (7,  'Physics',   10, '2024-01-01'), (7,  'Physics',   20, '2024-02-01'),
  (3,  'Math',      10, '2024-01-01'), (3,  'Math',      20, '2024-02-01'),
  (7,  'Math',      30, '2024-01-01'), (7,  'Math',      40, '2024-02-01'),
  (7,  'Chemistry', 50, '2024-01-01'), (7,  'Chemistry', 60, '2024-02-01');

-- expect: 3,Math,10,20 | smallest student_id first
-- expect: 7,Chemistry,50,60 | student 7: subjects in ascending order
-- expect: 7,Math,30,40 | second subject of student 7
-- expect: 7,Physics,10,20 | third subject of student 7
-- expect: 12,Art,10,20 | student 12 comes last although 'Art' sorts before every other subject
