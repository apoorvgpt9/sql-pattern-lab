-- breaks: edge_peak_and_valley
-- MISTAKE: LAST_VALUE with the DEFAULT window frame. With ORDER BY, the default frame ends at the CURRENT
-- ROW, so LAST_VALUE returns the current row's own score, not the pair's last. The result depends on the
-- row, and the GROUP BY keeps several rows per pair.
WITH w_scores AS (
  SELECT student_id, subject,
         FIRST_VALUE(score) OVER w AS first_score,
         LAST_VALUE(score)  OVER w AS latest_score
  FROM Scores
  WINDOW w AS (PARTITION BY student_id, subject ORDER BY exam_date)
)
SELECT student_id, subject, first_score, latest_score
FROM w_scores
WHERE latest_score > first_score
GROUP BY student_id, subject, first_score, latest_score
ORDER BY student_id, subject;
