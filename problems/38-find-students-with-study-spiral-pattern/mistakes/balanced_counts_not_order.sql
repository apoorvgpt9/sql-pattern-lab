-- breaks: edge_broken_sequence
-- MISTAKE: checking that every subject appears n_sessions / k times instead of checking the ORDER.
-- Lu studies A, B, C, A, C, B: each subject twice, 3 subjects, 6 sessions - balanced, but the
-- second cycle is not a repeat of the first. The rotation is about positions, not counts.
WITH ordered AS (
  SELECT student_id, subject, hours_studied,
         DATEDIFF(session_date, LAG(session_date) OVER (PARTITION BY student_id
                                                        ORDER BY session_date, session_id)) AS gap
  FROM study_sessions
),
per_subject AS (
  SELECT student_id, subject, COUNT(*) AS c FROM study_sessions GROUP BY student_id, subject
),
per_student AS (
  SELECT student_id, COUNT(*) AS n_sessions, COUNT(DISTINCT subject) AS k,
         SUM(hours_studied) AS total_hours, MAX(gap) AS max_gap
  FROM ordered GROUP BY student_id
)
SELECT st.student_id, st.student_name, st.major, p.k AS cycle_length, p.total_hours AS total_study_hours
FROM per_student p
JOIN students st ON st.student_id = p.student_id
WHERE p.k >= 3 AND p.n_sessions >= 2 * p.k AND p.n_sessions % p.k = 0 AND p.max_gap <= 2
  AND NOT EXISTS (SELECT 1 FROM per_subject s
                  WHERE s.student_id = p.student_id AND s.c <> p.n_sessions / p.k)
ORDER BY cycle_length DESC, total_study_hours DESC;
