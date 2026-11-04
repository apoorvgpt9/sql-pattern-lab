-- UNVERIFIED: Snowflake version of the optimal approach (03). CI cannot run Snowflake.
-- Snowflake allows COUNT(DISTINCT ...) OVER (PARTITION BY ...), so k joins the same window pass and
-- the ks join disappears. DATEDIFF takes (unit, start, end). See README section 9.
WITH ordered AS (
  SELECT student_id, subject, hours_studied,
         ROW_NUMBER() OVER w                                    AS n,
         DATEDIFF(day, LAG(session_date) OVER w, session_date)  AS gap,
         COUNT(DISTINCT subject) OVER (PARTITION BY student_id) AS k
  FROM study_sessions
  WINDOW w AS (PARTITION BY student_id ORDER BY session_date, session_id)
),
per_student AS (
  SELECT student_id, k,
         COUNT(*)                                AS n_sessions,
         SUM(hours_studied)                      AS total_hours,
         MAX(gap)                                AS max_gap,
         COUNT(DISTINCT MOD(n - 1, k), subject)  AS slot_subject_pairs
  FROM ordered
  WHERE k >= 3
  GROUP BY student_id, k
)
SELECT st.student_id, st.student_name, st.major,
       p.k AS cycle_length, p.total_hours AS total_study_hours
FROM per_student p
JOIN students st ON st.student_id = p.student_id
WHERE p.n_sessions >= 2 * p.k
  AND p.n_sessions % p.k = 0
  AND p.max_gap <= 2
  AND p.slot_subject_pairs = p.k
ORDER BY cycle_length DESC, total_study_hours DESC;
