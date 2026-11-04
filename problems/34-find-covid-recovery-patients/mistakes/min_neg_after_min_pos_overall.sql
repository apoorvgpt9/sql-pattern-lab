-- breaks: edge_negative_before_positive
-- MISTAKE: one-pass conditional aggregation of the patient's first negative and first positive,
-- then "first negative must be after first positive". A negative BEFORE the first positive becomes
-- the patient's MIN(negative), so a later real recovery is never seen (Hal disappears).
SELECT p.patient_id, p.patient_name, p.age,
       DATEDIFF(MIN(CASE WHEN t.result = 'Negative' THEN t.test_date END),
                MIN(CASE WHEN t.result = 'Positive' THEN t.test_date END)) AS recovery_time
FROM patients p
JOIN covid_tests t ON t.patient_id = p.patient_id
GROUP BY p.patient_id, p.patient_name, p.age
HAVING MIN(CASE WHEN t.result = 'Negative' THEN t.test_date END)
     > MIN(CASE WHEN t.result = 'Positive' THEN t.test_date END)
ORDER BY recovery_time, p.patient_name;
