-- Find Students with Study Spiral Pattern (LeetCode 3617): tables for MySQL 8.0. Names mirror the original.
-- No foreign key, as on LeetCode: a session may reference a student_id not in students.

CREATE TABLE students (
  student_id   INT PRIMARY KEY,     -- grain: one row per student
  student_name VARCHAR(100),
  major        VARCHAR(100)
);

CREATE TABLE study_sessions (
  session_id    INT PRIMARY KEY,    -- grain: one row per study session; also the same-day tiebreak
  student_id    INT,
  subject       VARCHAR(100),
  session_date  DATE,
  hours_studied DECIMAL(5,2)
);
