-- Gap rule: every gap between consecutive sessions must be at most 2 days.
-- Jo: three full cycles, every gap exactly 2 days (qualifies). Kai: one gap of 3 days (out).
INSERT INTO students (student_id, student_name, major) VALUES
  (1, 'Jo', 'Law'), (2, 'Kai', 'Law');

INSERT INTO study_sessions (session_id, student_id, subject, session_date, hours_studied) VALUES
  (1,  1, 'A', '2024-02-01', 1.00), (2,  1, 'B', '2024-02-03', 1.00),
  (3,  1, 'C', '2024-02-05', 1.00), (4,  1, 'A', '2024-02-07', 1.00),
  (5,  1, 'B', '2024-02-09', 1.00), (6,  1, 'C', '2024-02-11', 1.00),
  (7,  1, 'A', '2024-02-13', 1.00), (8,  1, 'B', '2024-02-15', 1.00),
  (9,  1, 'C', '2024-02-17', 1.00),                                    -- Jo: 9 sessions = 3 cycles
  (10, 2, 'A', '2024-02-01', 1.00), (11, 2, 'B', '2024-02-02', 1.00),
  (12, 2, 'C', '2024-02-03', 1.00), (13, 2, 'A', '2024-02-06', 1.00),  -- Kai: 02-03 -> 02-06 = 3 days
  (14, 2, 'B', '2024-02-07', 1.00), (15, 2, 'C', '2024-02-08', 1.00);

-- expect: 1,Jo,Law,3,9.00 | every DATEDIFF is exactly 2 (<= 2); 9 = 3 * 3 sessions; 9 * 1.00 = 9.00
