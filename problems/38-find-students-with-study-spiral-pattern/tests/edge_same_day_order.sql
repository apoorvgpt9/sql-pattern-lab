-- Sessions are ordered by (session_date, session_id). Nia has two sessions on 03-01 and two on 03-03.
-- In (date, id) order the subjects are A, B, C, A, B, C. In session_id order alone they are
-- C, A, B, A, B, C (id 1 is dated 03-02), which is not a cycle.
INSERT INTO students (student_id, student_name, major) VALUES
  (1, 'Nia', 'Chem');

INSERT INTO study_sessions (session_id, student_id, subject, session_date, hours_studied) VALUES
  (1, 1, 'C', '2024-03-02', 3.00),
  (2, 1, 'A', '2024-03-01', 1.00),
  (3, 1, 'B', '2024-03-01', 2.00),   -- same date as id 2: comes after it (higher session_id)
  (4, 1, 'A', '2024-03-03', 1.00),
  (5, 1, 'B', '2024-03-03', 2.00),
  (6, 1, 'C', '2024-03-04', 3.00);

-- expect: 1,Nia,Chem,3,12.00 | order (2,3,1,4,5,6) = A,B,C,A,B,C; gaps 0,1,1,0,1; 1+2+3+1+2+3 = 12.00
