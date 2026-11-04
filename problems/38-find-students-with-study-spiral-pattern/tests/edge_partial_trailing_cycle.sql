-- ASSUMPTION test: the session count must be a multiple of k. Hal has 2 full cycles plus one
-- extra session (7 sessions), so Hal is out; Ivy has exactly 2 cycles.
INSERT INTO students (student_id, student_name, major) VALUES
  (1, 'Hal', 'Bio'), (2, 'Ivy', 'Bio');

INSERT INTO study_sessions (session_id, student_id, subject, session_date, hours_studied) VALUES
  (1,  1, 'A', '2024-04-01', 1.00), (2,  1, 'B', '2024-04-02', 1.00),
  (3,  1, 'C', '2024-04-03', 1.00), (4,  1, 'A', '2024-04-04', 1.00),
  (5,  1, 'B', '2024-04-05', 1.00), (6,  1, 'C', '2024-04-06', 1.00),
  (7,  1, 'A', '2024-04-07', 1.00),                                    -- Hal: a started third cycle
  (8,  2, 'A', '2024-04-01', 2.00), (9,  2, 'B', '2024-04-02', 2.00),
  (10, 2, 'C', '2024-04-03', 2.00), (11, 2, 'A', '2024-04-04', 2.00),
  (12, 2, 'B', '2024-04-05', 2.00), (13, 2, 'C', '2024-04-06', 2.00);

-- expect: 2,Ivy,Bio,3,12.00 | 6 sessions, 6 % 3 = 0; 6 * 2.00 = 12.00 (Hal: 7 % 3 = 1, so not complete cycles)
