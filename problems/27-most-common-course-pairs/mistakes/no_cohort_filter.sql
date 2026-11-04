-- breaks: edge_typical, edge_thresholds, edge_no_top_performers
-- MISTAKE: Skipping the top-performer cohort (every user's transitions are counted).
WITH transitions AS (
  SELECT cc.course_name AS first_course,
         LEAD(cc.course_name) OVER (PARTITION BY cc.user_id ORDER BY cc.completion_date, cc.course_id) AS second_course
  FROM course_completions cc
)
SELECT first_course, second_course, COUNT(*) AS transition_count
FROM transitions
WHERE second_course IS NOT NULL
GROUP BY first_course, second_course
ORDER BY transition_count DESC, first_course ASC, second_course ASC;
