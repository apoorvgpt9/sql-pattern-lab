-- breaks: edge_peak_and_valley
-- MISTAKE: reads "improved" as "some exam scored higher than the exam before it" (LAG). Student 10 goes
-- 60 -> 95 -> 55, so a consecutive improvement exists, but the latest exam is below the first.
WITH x AS (
  SELECT student_id, subject, score, exam_date,
         LAG(score) OVER (PARTITION BY student_id, subject ORDER BY exam_date) AS prev_score,
         FIRST_VALUE(score) OVER (PARTITION BY student_id, subject ORDER BY exam_date) AS first_score,
         LAST_VALUE(score) OVER (PARTITION BY student_id, subject ORDER BY exam_date
                                 ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS latest_score
  FROM Scores
)
SELECT DISTINCT student_id, subject, first_score, latest_score
FROM x
WHERE score > prev_score
ORDER BY student_id, subject;
