-- breaks: edge_typical
-- MISTAKE: driving from covid_tests with a LEFT JOIN to patients. Tests for a patient_id that is
-- not in patients produce a row with NULL name and age. The output is "recovered patients", so
-- the patient must exist: an inner join (or driving from patients) is right here.
WITH first_pos AS (
  SELECT patient_id, MIN(test_date) AS pos_date
  FROM covid_tests WHERE result = 'Positive' GROUP BY patient_id
),
recovered AS (
  SELECT f.patient_id, DATEDIFF(MIN(n.test_date), f.pos_date) AS recovery_time
  FROM first_pos f
  JOIN covid_tests n ON n.patient_id = f.patient_id AND n.result = 'Negative' AND n.test_date > f.pos_date
  GROUP BY f.patient_id, f.pos_date
)
SELECT r.patient_id, p.patient_name, p.age, r.recovery_time
FROM recovered r
LEFT JOIN patients p ON p.patient_id = r.patient_id
ORDER BY r.recovery_time, p.patient_name;
