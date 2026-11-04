-- NULLs: a session with unknown hours still counts as a session in the pattern; its hours add
-- nothing to the total (SUM skips NULL). NULL major is passed through. Sessions of student 99,
-- who is not in students, are ignored even though they form a perfect cycle.
INSERT INTO students (student_id, student_name, major) VALUES
  (1, 'Oz', NULL);

INSERT INTO study_sessions (session_id, student_id, subject, session_date, hours_studied) VALUES
  (1,  1,  'A', '2024-06-01', 2.00), (2,  1,  'B', '2024-06-02', NULL),
  (3,  1,  'C', '2024-06-03', 2.00), (4,  1,  'A', '2024-06-04', 2.00),
  (5,  1,  'B', '2024-06-05', 2.00), (6,  1,  'C', '2024-06-06', 2.00),
  (7,  99, 'A', '2024-06-01', 1.00), (8,  99, 'B', '2024-06-02', 1.00),
  (9,  99, 'C', '2024-06-03', 1.00), (10, 99, 'A', '2024-06-04', 1.00),
  (11, 99, 'B', '2024-06-05', 1.00), (12, 99, 'C', '2024-06-06', 1.00);

-- expect: 1,Oz,NULL,3,10.00 | 6 sessions in the cycle; hours 2 + NULL + 2 + 2 + 2 + 2 = 10.00 (NULL skipped)
