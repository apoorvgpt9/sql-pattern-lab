-- Approach 3 (optimal): number each top performer's completions in order, then join row n to row n + 1.
-- ROW_NUMBER streams (no look-ahead buffer); the join on (user_id, rn + 1) is 1:1 per position.
-- The cohort is filtered first (GROUP BY / HAVING), so the window only sees top performers' rows.
WITH top_users AS (
  SELECT user_id
  FROM course_completions
  GROUP BY user_id
  HAVING COUNT(*) >= 5 AND SUM(course_rating) >= 4 * COUNT(course_rating)
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
