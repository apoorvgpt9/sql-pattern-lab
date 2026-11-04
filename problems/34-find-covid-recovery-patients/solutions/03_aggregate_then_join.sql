-- Approach 3 (optimal): two narrow passes over covid_tests, no full sort.
-- Pass 1: first positive per patient (GROUP BY) - one row per patient.
-- Pass 2: join that anchor to the negatives strictly later than it, take the MIN.
-- Each pass reads only one result type, and both are index range reads with indexes.sql.
WITH first_pos AS (
  SELECT patient_id, MIN(test_date) AS first_pos
  FROM covid_tests
  WHERE result = 'Positive'
  GROUP BY patient_id
),
recovered AS (
  SELECT f.patient_id, f.first_pos, MIN(n.test_date) AS first_neg_after
  FROM first_pos f
  JOIN covid_tests n
    ON  n.patient_id = f.patient_id
    AND n.result     = 'Negative'
    AND n.test_date  > f.first_pos
  GROUP BY f.patient_id, f.first_pos
)
SELECT p.patient_id, p.patient_name, p.age,
       DATEDIFF(r.first_neg_after, r.first_pos) AS recovery_time
FROM recovered r
JOIN patients p ON p.patient_id = r.patient_id
ORDER BY recovery_time, p.patient_name;
