-- breaks: edge_typical, edge_peak_and_valley, edge_date_strings, edge_no_improvement
-- MISTAKE: compares the best score with the worst score instead of the latest with the first. With only
-- two exams the answers coincide whenever the pair improves, so this passes simple data. A peak or dip
-- in the middle exposes it: the spec compares by DATE, not by size.
SELECT student_id, subject, MIN(score) AS first_score, MAX(score) AS latest_score
FROM Scores
GROUP BY student_id, subject
HAVING MAX(score) > MIN(score) AND COUNT(*) >= 2
ORDER BY student_id, subject;
