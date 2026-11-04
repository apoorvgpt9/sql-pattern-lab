-- Most Common Course Pairs (LeetCode 3764): tables for MySQL 8.0. Names mirror the original.

CREATE TABLE course_completions (
  user_id         INT,
  course_id       INT,
  course_name     VARCHAR(100),
  completion_date DATE,
  course_rating   INT,            -- 1-5
  PRIMARY KEY (user_id, course_id)   -- grain: one row per (user, completed course)
);
