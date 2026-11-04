-- UNVERIFIED: Snowflake version of the optimal approach (03). CI cannot run Snowflake.
-- Same shape as MySQL; the one behavioural difference is string ordering (README section 9).
WITH top_users AS (
  SELECT user_id
  FROM course_completions
  GROUP BY user_id
  HAVING COUNT(*) >= 5 AND SUM(course_rating) >= 4 * COUNT(*)
),
transitions AS (
  SELECT cc.course_name AS first_course,
         LEAD(cc.course_name) OVER (PARTITION BY cc.user_id
                                    ORDER BY cc.completion_date, cc.course_id) AS second_course
  FROM course_completions cc
  JOIN top_users t ON t.user_id = cc.user_id
)
SELECT first_course, second_course, COUNT(*) AS transition_count
FROM transitions
WHERE second_course IS NOT NULL
GROUP BY first_course, second_course
ORDER BY transition_count DESC,
         first_course  COLLATE 'en-ci' ASC,    -- default Snowflake ordering is case-sensitive; MySQL's is not
         second_course COLLATE 'en-ci' ASC;
