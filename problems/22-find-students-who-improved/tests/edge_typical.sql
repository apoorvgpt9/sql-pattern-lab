-- Typical mix: one improving pair, one declining pair of the SAME student (so subjects must not be
-- mixed), an equal pair, a single exam, and another improving student.
INSERT INTO Scores (student_id, subject, score, exam_date) VALUES
  (4, 'Math',      95, '2024-06-01'),
  (1, 'Physics',   80, '2024-03-07'),
  (1, 'Math',      85, '2024-03-05'),
  (2, 'Math',      60, '2024-04-01'),
  (3, 'Chemistry', 55, '2024-02-02'),
  (1, 'Math',      70, '2024-01-10'),
  (2, 'Math',      60, '2024-02-01'),
  (1, 'Physics',   90, '2024-01-12'),
  (4, 'Math',      40, '2024-05-01');

-- expect: 1,Math,70,85 | Math: first exam 01-10 scored 70, latest 03-05 scored 85: improved (Physics is a separate pair)
-- expect: 4,Math,40,95 | first 05-01 scored 40, latest 06-01 scored 95: improved
-- (1/Physics fell from 90 to 80; 2/Math is equal at 60; 3/Chemistry has a single exam.)
