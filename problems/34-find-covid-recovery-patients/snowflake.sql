-- UNVERIFIED: Snowflake version of the optimal approach (03). CI cannot run Snowflake.
-- Note DATEDIFF(unit, start, end): the argument order is the reverse of MySQL's DATEDIFF(end, start).
-- String comparison is case-sensitive in Snowflake by default. Differences are in README section 9.
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
       DATEDIFF(day, r.first_pos, r.first_neg_after) AS recovery_time
FROM recovered r
JOIN patients p ON p.patient_id = r.patient_id
ORDER BY recovery_time, p.patient_name;
