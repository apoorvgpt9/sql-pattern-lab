-- breaks: edge_first_positive_anchor
-- MISTAKE: anchoring on the latest positive (MAX) instead of the first one. With a re-infection,
-- the recovery is measured from the wrong positive.
WITH last_pos AS (
  SELECT patient_id, MAX(test_date) AS pos_date
  FROM covid_tests WHERE result = 'Positive' GROUP BY patient_id
)
SELECT p.patient_id, p.patient_name, p.age,
       DATEDIFF(MIN(n.test_date), f.pos_date) AS recovery_time
FROM last_pos f
JOIN covid_tests n ON n.patient_id = f.patient_id AND n.result = 'Negative' AND n.test_date > f.pos_date
JOIN patients p ON p.patient_id = f.patient_id
GROUP BY p.patient_id, p.patient_name, p.age, f.pos_date
ORDER BY recovery_time, p.patient_name;
