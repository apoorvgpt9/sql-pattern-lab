-- Right counts, wrong order. Lu has 3 subjects, 6 sessions, each subject twice, but the second
-- cycle is A, C, B. Mo repeats the block A, B, A, C twice: 3 distinct subjects, 8 sessions,
-- 8 % 3 <> 0, so Mo is out (a "smallest repeating block = 4" reading would wrongly accept Mo).
INSERT INTO students (student_id, student_name, major) VALUES
  (1, 'Lu', 'Art'), (2, 'Mo', 'Art');

INSERT INTO study_sessions (session_id, student_id, subject, session_date, hours_studied) VALUES
  (1,  1, 'A', '2024-05-01', 1.00), (2,  1, 'B', '2024-05-02', 1.00),
  (3,  1, 'C', '2024-05-03', 1.00), (4,  1, 'A', '2024-05-04', 1.00),
  (5,  1, 'C', '2024-05-05', 1.00), (6,  1, 'B', '2024-05-06', 1.00),
  (7,  2, 'A', '2024-05-01', 1.00), (8,  2, 'B', '2024-05-02', 1.00),
  (9,  2, 'A', '2024-05-03', 1.00), (10, 2, 'C', '2024-05-04', 1.00),
  (11, 2, 'A', '2024-05-05', 1.00), (12, 2, 'B', '2024-05-06', 1.00),
  (13, 2, 'A', '2024-05-07', 1.00), (14, 2, 'C', '2024-05-08', 1.00);

-- expect-empty: Lu's session 5 is C where the cycle says B; Mo has 8 sessions, not a multiple of k = 3
