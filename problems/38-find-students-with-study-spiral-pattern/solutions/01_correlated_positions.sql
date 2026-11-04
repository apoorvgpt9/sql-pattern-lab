-- Approach 1 (brute force): no window functions. A session's position n is the number of the
-- student's sessions at or before it in (session_date, session_id) order (correlated COUNT).
-- Then two NOT EXISTS checks, each a direct reading of one rule:
--   * no consecutive pair (n, n+1) more than 2 days apart;
--   * no session whose subject differs from the session in its slot of the first cycle,
--     position ((n - 1) mod k) + 1.
WITH pos AS (
  SELECT s.student_id, s.subject, s.session_date,
         (SELECT COUNT(*) FROM study_sessions t
           WHERE t.student_id = s.student_id
             AND (t.session_date < s.session_date
                  OR (t.session_date = s.session_date AND t.session_id <= s.session_id))) AS n
  FROM study_sessions s
),
per_student AS (
  SELECT student_id, COUNT(*) AS n_sessions, COUNT(DISTINCT subject) AS k,
         SUM(hours_studied) AS total_hours
  FROM study_sessions
  GROUP BY student_id
)
SELECT st.student_id, st.student_name, st.major,
       ps.k           AS cycle_length,
       ps.total_hours AS total_study_hours
FROM per_student ps
JOIN students st ON st.student_id = ps.student_id
WHERE ps.k >= 3
  AND ps.n_sessions >= 2 * ps.k
  AND ps.n_sessions % ps.k = 0
  AND NOT EXISTS (SELECT 1 FROM pos a
                  JOIN pos b ON b.student_id = a.student_id AND b.n = a.n + 1
                  WHERE a.student_id = ps.student_id
                    AND DATEDIFF(b.session_date, a.session_date) > 2)
  AND NOT EXISTS (SELECT 1 FROM pos x
                  JOIN pos f ON f.student_id = x.student_id AND f.n = MOD(x.n - 1, ps.k) + 1
                  WHERE x.student_id = ps.student_id
                    AND x.subject <> f.subject)
ORDER BY cycle_length DESC, total_study_hours DESC;
