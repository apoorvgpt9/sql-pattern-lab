-- Approach 2: one GROUP BY finds the first and the last exam date of every (student, subject); then
-- Scores is joined twice, once on each date, to read the two scores.
WITH ends AS (
  SELECT student_id, subject, MIN(exam_date) AS first_date, MAX(exam_date) AS last_date
  FROM Scores
  GROUP BY student_id, subject
  HAVING COUNT(*) >= 2
)
SELECT
  e.student_id,
  e.subject,
  f.score AS first_score,
  l.score AS latest_score
FROM ends e
JOIN Scores f ON f.student_id = e.student_id AND f.subject = e.subject AND f.exam_date = e.first_date
JOIN Scores l ON l.student_id = e.student_id AND l.subject = e.subject AND l.exam_date = e.last_date
WHERE l.score > f.score
ORDER BY e.student_id, e.subject;
