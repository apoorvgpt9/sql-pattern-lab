-- breaks: edge_typical, edge_ordering
-- MISTAKE: partitions the window by student_id and forgets subject. The "first" and "latest" scores then
-- come from whatever subject the student sat first/last, and are attached to every subject of that student.
WITH w_scores AS (
  SELECT student_id, subject,
         FIRST_VALUE(score) OVER w AS first_score,
         LAST_VALUE(score)  OVER w AS latest_score
  FROM Scores
  WINDOW w AS (PARTITION BY student_id ORDER BY exam_date
               ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING)
)
SELECT student_id, subject, first_score, latest_score
FROM w_scores
WHERE latest_score > first_score
GROUP BY student_id, subject, first_score, latest_score
ORDER BY student_id, subject;
