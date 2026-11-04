-- breaks: edge_nulls
-- MISTAKE: picking the first positive with ROW_NUMBER() ... ORDER BY test_date. MySQL sorts NULL
-- first in ascending order, so an undated positive becomes the "first" one, the date comparison
-- with NULL is never true, and the patient vanishes (Ned). MIN() skips NULLs; ORDER BY does not.
WITH ranked_pos AS (
  SELECT patient_id, test_date,
         ROW_NUMBER() OVER (PARTITION BY patient_id ORDER BY test_date) AS rn
  FROM covid_tests WHERE result = 'Positive'
),
first_pos AS (SELECT patient_id, test_date AS pos_date FROM ranked_pos WHERE rn = 1)
SELECT p.patient_id, p.patient_name, p.age,
       DATEDIFF(MIN(n.test_date), f.pos_date) AS recovery_time
FROM first_pos f
JOIN covid_tests n ON n.patient_id = f.patient_id AND n.result = 'Negative' AND n.test_date > f.pos_date
JOIN patients p ON p.patient_id = f.patient_id
GROUP BY p.patient_id, p.patient_name, p.age, f.pos_date
ORDER BY recovery_time, p.patient_name;
