-- Approach 2: ROW_NUMBER for positions and LAG for gaps in one window pass; per-student counts in a
-- GROUP BY; then a self-join of each session to its anchor (the session in the same slot of the
-- first cycle) to find mismatches, removed with NOT EXISTS.
WITH ordered AS (
  SELECT student_id, subject, hours_studied,
         ROW_NUMBER() OVER w                              AS n,
         DATEDIFF(session_date, LAG(session_date) OVER w) AS gap
  FROM study_sessions
  WINDOW w AS (PARTITION BY student_id ORDER BY session_date, session_id)
),
per_student AS (
  SELECT student_id, COUNT(*) AS n_sessions, COUNT(DISTINCT subject) AS k,
         SUM(hours_studied) AS total_hours, MAX(gap) AS max_gap
  FROM ordered
  GROUP BY student_id
),
candidates AS (
  SELECT * FROM per_student
  WHERE k >= 3 AND n_sessions >= 2 * k AND n_sessions % k = 0 AND max_gap <= 2
)
SELECT st.student_id, st.student_name, st.major,
       c.k           AS cycle_length,
       c.total_hours AS total_study_hours
FROM candidates c
JOIN students st ON st.student_id = c.student_id
WHERE NOT EXISTS (SELECT 1
                  FROM ordered o
                  JOIN ordered f ON f.student_id = o.student_id AND f.n = MOD(o.n - 1, c.k) + 1
                  WHERE o.student_id = c.student_id
                    AND o.subject <> f.subject)
ORDER BY cycle_length DESC, total_study_hours DESC;
