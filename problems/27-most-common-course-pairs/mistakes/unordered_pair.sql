-- breaks: edge_typical, edge_ordering
-- MISTAKE: Treating a transition as an unordered pair (LEAST/GREATEST): A>B and B>A merge and the direction is lost.
WITH top_users AS (
  SELECT user_id FROM course_completions
  GROUP BY user_id
  HAVING COUNT(*) >= 5 AND SUM(course_rating) >= 4 * COUNT(*)
),
transitions AS (
  SELECT cc.course_name AS a,
         LEAD(cc.course_name) OVER (PARTITION BY cc.user_id ORDER BY cc.completion_date, cc.course_id) AS b
  FROM course_completions cc JOIN top_users t ON t.user_id = cc.user_id
)
SELECT LEAST(a, b) AS first_course, GREATEST(a, b) AS second_course, COUNT(*) AS transition_count
FROM transitions
WHERE b IS NOT NULL
GROUP BY LEAST(a, b), GREATEST(a, b)
ORDER BY transition_count DESC, first_course ASC, second_course ASC;
