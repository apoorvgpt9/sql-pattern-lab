-- breaks: edge_typical, edge_no_improvement
-- MISTAKE: latest >= first instead of latest > first. Equal scores (and every single-exam pair, whose first
-- and latest are the same row) are then reported as improved.
SELECT f.student_id, f.subject, f.score AS first_score, l.score AS latest_score
FROM Scores f
JOIN Scores l ON l.student_id = f.student_id AND l.subject = f.subject
WHERE f.exam_date = (SELECT MIN(a.exam_date) FROM Scores a WHERE a.student_id = f.student_id AND a.subject = f.subject)
  AND l.exam_date = (SELECT MAX(b.exam_date) FROM Scores b WHERE b.student_id = l.student_id AND b.subject = l.subject)
  AND l.score >= f.score
ORDER BY f.student_id, f.subject;
