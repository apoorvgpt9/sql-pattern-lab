-- breaks: edge_typical
-- MISTAKE: treating every non-positive result as a negative (result <> 'Positive'). An
-- Inconclusive test after the positive then ends the recovery early (Bob: 3 instead of 7).
WITH first_pos AS (
  SELECT patient_id, MIN(test_date) AS pos_date
  FROM covid_tests WHERE result = 'Positive' GROUP BY patient_id
)
SELECT p.patient_id, p.patient_name, p.age,
       DATEDIFF(MIN(n.test_date), f.pos_date) AS recovery_time
FROM first_pos f
JOIN covid_tests n ON n.patient_id = f.patient_id AND n.result <> 'Positive' AND n.test_date > f.pos_date
JOIN patients p ON p.patient_id = f.patient_id
GROUP BY p.patient_id, p.patient_name, p.age, f.pos_date
ORDER BY recovery_time, p.patient_name;
