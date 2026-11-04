-- Output order: cycle_length DESC comes first. Dia (k = 4, 8 hours) precedes Eve (k = 3, 12 hours)
-- even though Eve studied more.
INSERT INTO students (student_id, student_name, major) VALUES
  (1, 'Eve', 'CS'), (2, 'Dia', 'CS');

INSERT INTO study_sessions (session_id, student_id, subject, session_date, hours_studied) VALUES
  (1,  2, 'W', '2024-02-01', 1.00), (2,  2, 'X', '2024-02-02', 1.00),
  (3,  2, 'Y', '2024-02-03', 1.00), (4,  2, 'Z', '2024-02-04', 1.00),
  (5,  2, 'W', '2024-02-05', 1.00), (6,  2, 'X', '2024-02-06', 1.00),
  (7,  2, 'Y', '2024-02-07', 1.00), (8,  2, 'Z', '2024-02-08', 1.00),
  (9,  1, 'A', '2024-02-01', 2.00), (10, 1, 'B', '2024-02-02', 2.00),
  (11, 1, 'C', '2024-02-03', 2.00), (12, 1, 'A', '2024-02-04', 2.00),
  (13, 1, 'B', '2024-02-05', 2.00), (14, 1, 'C', '2024-02-06', 2.00);

-- expect: 2,Dia,CS,4,8.00 | k = 4 (W, X, Y, Z), 8 = 2 * 4 sessions, 8 * 1.00 = 8.00; larger cycle first
-- expect: 1,Eve,CS,3,12.00 | k = 3, 6 = 2 * 3 sessions, 6 * 2.00 = 12.00
