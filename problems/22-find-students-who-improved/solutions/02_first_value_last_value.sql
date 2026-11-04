-- Approach 2: one scan. FIRST_VALUE and LAST_VALUE over the same window (partition = one
-- student-subject pair, ordered by exam_date, frame = the whole partition) put the first and the latest
-- score on every row; the outer GROUP BY collapses each pair back to a single row.
-- The named window w is shared, so MySQL sorts the data once for both functions.
WITH w_scores AS (
  SELECT
    student_id,
    subject,
    FIRST_VALUE(score) OVER w AS first_score,
    LAST_VALUE(score)  OVER w AS latest_score
  FROM Scores
  WINDOW w AS (PARTITION BY student_id, subject
               ORDER BY exam_date
               ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING)
)
SELECT student_id, subject, first_score, latest_score
FROM w_scores
WHERE latest_score > first_score
GROUP BY student_id, subject, first_score, latest_score
ORDER BY student_id, subject;
