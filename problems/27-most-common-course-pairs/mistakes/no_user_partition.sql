-- breaks: edge_typical, edge_ordering
-- MISTAKE: LEAD without PARTITION BY user_id: the last course of one user is paired with the first course of the next user.
WITH top_users AS (
  SELECT user_id FROM course_completions
  GROUP BY user_id
  HAVING COUNT(*) >= 5 AND SUM(course_rating) >= 4 * COUNT(*)
),
transitions AS (
  SELECT cc.course_name AS first_course,
         LEAD(cc.course_name) OVER (ORDER BY cc.user_id, cc.completion_date, cc.course_id) AS second_course
  FROM course_completions cc JOIN top_users t ON t.user_id = cc.user_id
)
SELECT first_course, second_course, COUNT(*) AS transition_count
FROM transitions
WHERE second_course IS NOT NULL
GROUP BY first_course, second_course
ORDER BY transition_count DESC, first_course ASC, second_course ASC;
