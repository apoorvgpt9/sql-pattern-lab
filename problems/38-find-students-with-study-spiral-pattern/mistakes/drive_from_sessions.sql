-- breaks: edge_nulls
-- MISTAKE: LEFT JOIN from the session-level result to students. Student 99 is not in students but
-- has a perfect cycle; the output needs a name, so the join to students must be inner.
WITH ordered AS (
  SELECT student_id, subject, hours_studied,
         ROW_NUMBER() OVER w AS n,
         DATEDIFF(session_date, LAG(session_date) OVER w) AS gap
  FROM study_sessions
  WINDOW w AS (PARTITION BY student_id ORDER BY session_date, session_id)
),
ks AS (
  SELECT student_id, COUNT(DISTINCT subject) AS k
  FROM study_sessions GROUP BY student_id HAVING COUNT(DISTINCT subject) >= 3
),
per_student AS (
  SELECT o.student_id, ks.k, COUNT(*) AS n_sessions, SUM(o.hours_studied) AS total_hours,
         MAX(o.gap) AS max_gap, COUNT(DISTINCT MOD(o.n - 1, ks.k), o.subject) AS slot_subject_pairs
  FROM ordered o JOIN ks ON ks.student_id = o.student_id
  GROUP BY o.student_id, ks.k
)
SELECT p.student_id, st.student_name, st.major, p.k AS cycle_length, p.total_hours AS total_study_hours
FROM per_student p
LEFT JOIN students st ON st.student_id = p.student_id
WHERE p.n_sessions >= 2 * p.k AND p.n_sessions % p.k = 0 AND p.max_gap <= 2 AND p.slot_subject_pairs = p.k
ORDER BY cycle_length DESC, total_study_hours DESC;
