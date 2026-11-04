-- Approach 1 (brute force): join each pair's first-exam row and latest-exam row, both located by a
-- correlated MIN/MAX of exam_date, and keep the pairs where the latest score is higher.
-- A pair with a single exam has first row = latest row, so "latest > first" is false: no separate
-- "at least two exams" test is needed.
SELECT
  f.student_id,
  f.subject,
  f.score AS first_score,
  l.score AS latest_score
FROM Scores f
JOIN Scores l
  ON  l.student_id = f.student_id
  AND l.subject    = f.subject
WHERE f.exam_date = (SELECT MIN(a.exam_date) FROM Scores a
                      WHERE a.student_id = f.student_id AND a.subject = f.subject)
  AND l.exam_date = (SELECT MAX(b.exam_date) FROM Scores b
                      WHERE b.student_id = l.student_id AND b.subject = l.subject)
  AND l.score > f.score
ORDER BY f.student_id, f.subject;
