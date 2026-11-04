-- Approach 2: one pass over covid_tests. A partition-only window puts each patient's first
-- positive date on every one of their rows; a single conditional MIN then picks the first negative
-- strictly after it. Only then join the (small) per-patient result to patients.
-- One pass, but the window has to sort the whole table by patient_id (see README section 5).
WITH anchored AS (
  SELECT patient_id, test_date, result,
         MIN(CASE WHEN result = 'Positive' THEN test_date END)
           OVER (PARTITION BY patient_id) AS first_pos
  FROM covid_tests
),
recovered AS (
  SELECT patient_id, first_pos,
         MIN(CASE WHEN result = 'Negative' AND test_date > first_pos THEN test_date END) AS first_neg_after
  FROM anchored
  WHERE first_pos IS NOT NULL
  GROUP BY patient_id, first_pos
)
SELECT p.patient_id, p.patient_name, p.age,
       DATEDIFF(r.first_neg_after, r.first_pos) AS recovery_time
FROM recovered r
JOIN patients p ON p.patient_id = r.patient_id
WHERE r.first_neg_after IS NOT NULL
ORDER BY recovery_time, p.patient_name;
