-- Typical: Ann studies 3 subjects in a fixed rotation for exactly 2 cycles on consecutive days.
-- Ben rotates perfectly too, but only 2 subjects (cycle length must be >= 3). Cy has no sessions.
INSERT INTO students (student_id, student_name, major) VALUES
  (1, 'Ann', 'Physics'), (2, 'Ben', 'Math'), (3, 'Cy', 'Art');

INSERT INTO study_sessions (session_id, student_id, subject, session_date, hours_studied) VALUES
  (1,  1, 'Math',    '2024-01-01', 1.50),
  (2,  1, 'Physics', '2024-01-02', 2.00),
  (3,  1, 'Chem',    '2024-01-03', 1.00),
  (4,  1, 'Math',    '2024-01-04', 1.50),
  (5,  1, 'Physics', '2024-01-05', 2.00),
  (6,  1, 'Chem',    '2024-01-06', 1.00),
  (7,  2, 'Algebra', '2024-01-01', 2.00),
  (8,  2, 'Stats',   '2024-01-02', 2.00),
  (9,  2, 'Algebra', '2024-01-03', 2.00),
  (10, 2, 'Stats',   '2024-01-04', 2.00);   -- Ben: k = 2

-- expect: 1,Ann,Physics,3,9.00 | k = 3 (Math, Physics, Chem); 6 = 2 * 3 sessions; gaps all 1 day; 1.5 + 2 + 1 + 1.5 + 2 + 1 = 9.00
