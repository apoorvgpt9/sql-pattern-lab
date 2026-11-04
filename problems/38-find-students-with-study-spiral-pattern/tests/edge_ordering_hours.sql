-- Output order on a cycle_length tie: total_study_hours DESC. student_id runs the other way.
INSERT INTO students (student_id, student_name, major) VALUES
  (1, 'Fox', 'EE'), (2, 'Gia', 'EE');

INSERT INTO study_sessions (session_id, student_id, subject, session_date, hours_studied) VALUES
  (1,  1, 'A', '2024-03-01', 1.00), (2,  1, 'B', '2024-03-02', 1.00),
  (3,  1, 'C', '2024-03-03', 1.00), (4,  1, 'A', '2024-03-04', 1.00),
  (5,  1, 'B', '2024-03-05', 1.00), (6,  1, 'C', '2024-03-06', 1.00),
  (7,  2, 'A', '2024-03-01', 1.50), (8,  2, 'B', '2024-03-02', 1.50),
  (9,  2, 'C', '2024-03-03', 1.50), (10, 2, 'A', '2024-03-04', 1.50),
  (11, 2, 'B', '2024-03-05', 1.50), (12, 2, 'C', '2024-03-06', 1.50);

-- expect: 2,Gia,EE,3,9.00 | 6 * 1.50 = 9.00: more hours first on equal cycle length
-- expect: 1,Fox,EE,3,6.00 | 6 * 1.00 = 6.00
