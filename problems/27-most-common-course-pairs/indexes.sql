-- Index recommended in README "At scale" (b). The bench runs every solution without it, then with it.
-- (user_id, completion_date, course_id, course_rating, course_name) is covering for all three solutions and
-- delivers each user's completions already in (date, id) order:
--   01: the correlated NOT EXISTS becomes a covering index range read per candidate pair;
--   02/03: the PARTITION BY user_id ORDER BY completion_date, course_id window reads a narrow index
--          instead of the clustered table (whether the optimizer then skips the window sort is checked in the bench EXPLAIN).
CREATE INDEX idx_cc_user_date ON course_completions (user_id, completion_date, course_id, course_rating, course_name);
