-- breaks: edge_thresholds
-- MISTAKE: Filtering COURSES with a low rating (WHERE course_rating >= 4) instead of filtering USERS by their average. Besides
-- dropping the wrong users, removing rows also changes which courses are adjacent in a user's sequence.
WITH top_users AS (
  SELECT user_id FROM course_completions
  WHERE course_rating >= 4
  GROUP BY user_id
  HAVING COUNT(*) >= 5
),
transitions AS (
  SELECT cc.course_name AS first_course,
         LEAD(cc.course_name) OVER (PARTITION BY cc.user_id ORDER BY cc.completion_date, cc.course_id) AS second_course
  FROM course_completions cc JOIN top_users t ON t.user_id = cc.user_id
  WHERE cc.course_rating >= 4
)
SELECT first_course, second_course, COUNT(*) AS transition_count
FROM transitions
WHERE second_course IS NOT NULL
GROUP BY first_course, second_course
ORDER BY transition_count DESC, first_course ASC, second_course ASC;
