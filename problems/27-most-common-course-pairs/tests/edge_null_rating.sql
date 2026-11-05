-- An unrated completion (course_rating NULL) still counts as a completed course, and the average is
-- over the rated courses only, as AVG(course_rating) computes it (README Assumptions 3).
-- User 1: 5 completions; rated 5+5+4+4 = 18 over 4 rated -> average 4.5 -> top performer.
-- User 2: 5 completions; rated 4+4+4+4 = 16 over 4 rated -> average exactly 4.0 -> top performer.
-- User 3: 5 completions, none rated -> AVG is NULL -> not a top performer.
-- Treating NULL as 0 (SUM >= 4 * COUNT(*)) gives 18 < 20 and 16 < 20, so nobody would qualify.
INSERT INTO course_completions (user_id, course_id, course_name, completion_date, course_rating) VALUES
  (1, 1, 'Algebra',   '2024-01-01', 5),
  (1, 2, 'Biology',   '2024-01-02', 5),
  (1, 3, 'Chemistry', '2024-01-03', NULL),   -- unrated, but still in the sequence
  (1, 4, 'Drawing',   '2024-01-04', 4),
  (1, 5, 'Economics', '2024-01-05', 4),
  (2, 1, 'Algebra',   '2024-02-01', 4),
  (2, 2, 'Biology',   '2024-02-02', 4),
  (2, 3, 'Chemistry', '2024-02-03', 4),
  (2, 4, 'Drawing',   '2024-02-04', NULL),   -- unrated
  (2, 6, 'French',    '2024-02-05', 4),
  (3, 1, 'Algebra',   '2024-03-01', NULL),
  (3, 2, 'Biology',   '2024-03-02', NULL),
  (3, 3, 'Chemistry', '2024-03-03', NULL),
  (3, 4, 'Drawing',   '2024-03-04', NULL),
  (3, 5, 'Economics', '2024-03-05', NULL);

-- expect: Algebra,Biology,2 | users 1 and 2 (user 3 is not a top performer)
-- expect: Biology,Chemistry,2 | users 1 and 2
-- expect: Chemistry,Drawing,2 | users 1 and 2; user 1's unrated Chemistry is still a completion in the sequence
-- expect: Drawing,Economics,1 | user 1 only; ties on 1 with Drawing->French, 'Economics' < 'French'
-- expect: Drawing,French,1 | user 2 only
