-- breaks: edge_same_day
-- MISTAKE: >= instead of >. A negative on the day of the first positive is not "after" it;
-- counting it gives recovery_time 0.
WITH first_pos AS (
  SELECT patient_id, MIN(test_date) AS pos_date
  FROM covid_tests WHERE result = 'Positive' GROUP BY patient_id
)
SELECT p.patient_id, p.patient_name, p.age,
       DATEDIFF(MIN(n.test_date), f.pos_date) AS recovery_time
FROM first_pos f
JOIN covid_tests n ON n.patient_id = f.patient_id AND n.result = 'Negative' AND n.test_date >= f.pos_date
JOIN patients p ON p.patient_id = f.patient_id
GROUP BY p.patient_id, p.patient_name, p.age, f.pos_date
ORDER BY recovery_time, p.patient_name;
