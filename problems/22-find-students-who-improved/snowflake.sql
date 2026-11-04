-- UNVERIFIED: Snowflake version of the aggregate-the-extremes idea (approaches 02/03): first and latest
-- score per pair in one scan. MIN_BY/MAX_BY return the score at the smallest/largest exam_date; exam_date is unique
-- within a (student, subject), so there are no ties to resolve.
SELECT
  student_id,
  subject,
  MIN_BY(score, exam_date) AS first_score,
  MAX_BY(score, exam_date) AS latest_score
FROM Scores
GROUP BY student_id, subject
HAVING MAX_BY(score, exam_date) > MIN_BY(score, exam_date)
ORDER BY student_id, subject;
