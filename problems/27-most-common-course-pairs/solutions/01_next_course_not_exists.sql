-- Approach 1 (brute force): for each completion A of a top performer, find every later completion B of the same
-- user, and keep the pair only if nothing happened between A and B (NOT EXISTS) - i.e. B is A's direct successor.
-- "Later" is (completion_date, course_id), the tie-break from README Assumptions.
-- Top performer: >= 5 courses and average rating >= 4, written as SUM >= 4 * COUNT (exact integer arithmetic).
SELECT a.course_name AS first_course,
       b.course_name AS second_course,
       COUNT(*)      AS transition_count
FROM course_completions a
JOIN course_completions b
  ON  b.user_id = a.user_id
  AND (b.completion_date, b.course_id) > (a.completion_date, a.course_id)
WHERE a.user_id IN (SELECT user_id
                      FROM course_completions
                     GROUP BY user_id
                    HAVING COUNT(*) >= 5 AND SUM(course_rating) >= 4 * COUNT(course_rating))
  AND NOT EXISTS (SELECT 1
                    FROM course_completions c
                   WHERE c.user_id = a.user_id
                     AND (c.completion_date, c.course_id) > (a.completion_date, a.course_id)
                     AND (c.completion_date, c.course_id) < (b.completion_date, b.course_id))
GROUP BY a.course_name, b.course_name
ORDER BY transition_count DESC, first_course ASC, second_course ASC;
