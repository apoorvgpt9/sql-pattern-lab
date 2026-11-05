-- breaks: edge_null_rating
-- MISTAKE: SUM(course_rating) >= 4 * COUNT(*) divides by every completion, so an unrated course
-- (NULL rating) counts as a 0 in the average. AVG(course_rating) skips it; the exact-integer form of AVG is
-- SUM(course_rating) >= 4 * COUNT(course_rating).
WITH top_users AS (
  SELECT user_id
  FROM course_completions
  GROUP BY user_id
  HAVING COUNT(*) >= 5 AND SUM(course_rating) >= 4 * COUNT(*)
),
numbered AS (
  SELECT cc.user_id, cc.course_name,
         ROW_NUMBER() OVER (PARTITION BY cc.user_id ORDER BY cc.completion_date, cc.course_id) AS rn
  FROM course_completions cc
  JOIN top_users t ON t.user_id = cc.user_id
)
SELECT a.course_name AS first_course,
       b.course_name AS second_course,
       COUNT(*)      AS transition_count
FROM numbered a
JOIN numbered b
  ON b.user_id = a.user_id AND b.rn = a.rn + 1
GROUP BY a.course_name, b.course_name
ORDER BY transition_count DESC, first_course ASC, second_course ASC;
