-- Find Students Who Improved (LeetCode 3421): tables for MySQL 8.0. Names mirror the original.
-- exam_date is a VARCHAR holding an ISO 'YYYY-MM-DD' string, as in the original: because the format is
-- zero-padded ISO, string order equals date order, so ORDER BY / MIN / MAX on it are chronological.

CREATE TABLE Scores (
  student_id INT NOT NULL,
  subject    VARCHAR(100) NOT NULL,
  score      INT NOT NULL,            -- 0-100
  exam_date  VARCHAR(10) NOT NULL,    -- ISO 'YYYY-MM-DD'
  PRIMARY KEY (student_id, subject, exam_date)   -- grain: one row per exam of one student in one subject
);
