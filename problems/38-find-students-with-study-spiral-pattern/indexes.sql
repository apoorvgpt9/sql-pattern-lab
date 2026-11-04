-- Index recommended in README "At scale" (b). The bench runs every solution without it, then with it.
-- (student_id, session_date, session_id, subject) is the session order the spec defines, and it
-- covers every column the position / gap / slot logic reads (hours_studied is only summed):
--   01: each correlated position COUNT becomes an index range read of one student's earlier
--       sessions instead of a full scan per session;
--   02, 03: the window's PARTITION BY student_id ORDER BY session_date, session_id matches the
--       index order (EXPLAIN shows whether MySQL still sorts); the k GROUP BY reads the index.
CREATE INDEX idx_sessions_student_date_id ON study_sessions (student_id, session_date, session_id, subject);
