-- breaks: edge_ordering
-- MISTAKE: Counting pairs by course_id and showing names: two editions of one course (same name, different ids) are
-- counted separately, so the same displayed pair appears in several rows.
WITH top_users AS (
  SELECT user_id FROM course_completions
  GROUP BY user_id
  HAVING COUNT(*) >= 5 AND SUM(course_rating) >= 4 * COUNT(course_rating)
),
transitions AS (
  SELECT cc.course_id AS first_id, cc.course_name AS first_course,
         LEAD(cc.course_id)   OVER w AS second_id,
         LEAD(cc.course_name) OVER w AS second_course
  FROM course_completions cc JOIN top_users t ON t.user_id = cc.user_id
  WINDOW w AS (PARTITION BY cc.user_id ORDER BY cc.completion_date, cc.course_id)
)
SELECT first_course, second_course, COUNT(*) AS transition_count
FROM transitions
WHERE second_id IS NOT NULL
GROUP BY first_id, first_course, second_id, second_course
ORDER BY transition_count DESC, first_course ASC, second_course ASC;
