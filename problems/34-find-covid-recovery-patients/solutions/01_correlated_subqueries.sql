-- Approach 1 (brute force): for each patient, look up the first positive date, then the first
-- negative date after it, with correlated subqueries. Reads like the spec, one patient at a time.
-- MIN() ignores NULL dates, and a comparison with a NULL date is never true, so undated tests drop out.
WITH per_patient AS (
  SELECT p.patient_id, p.patient_name, p.age,
         (SELECT MIN(t.test_date) FROM covid_tests t
           WHERE t.patient_id = p.patient_id AND t.result = 'Positive') AS first_pos,
         (SELECT MIN(n.test_date) FROM covid_tests n
           WHERE n.patient_id = p.patient_id AND n.result = 'Negative'
             AND n.test_date > (SELECT MIN(t.test_date) FROM covid_tests t
                                 WHERE t.patient_id = p.patient_id AND t.result = 'Positive')) AS first_neg_after
  FROM patients p
)
SELECT patient_id, patient_name, age,
       DATEDIFF(first_neg_after, first_pos) AS recovery_time
FROM per_patient
WHERE first_neg_after IS NOT NULL
ORDER BY recovery_time, patient_name;
