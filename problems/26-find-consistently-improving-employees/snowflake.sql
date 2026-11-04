-- UNVERIFIED: Snowflake version of the optimal approach (03). CI cannot run Snowflake.
-- QUALIFY filters on a window function directly, and Snowflake has no named WINDOW clause,
-- so the window spec is repeated. Differences are noted in README section 9.
WITH latest AS (
  SELECT employee_id,
         rating AS newest,
         LEAD(rating, 1) OVER (PARTITION BY employee_id ORDER BY review_date DESC, review_id DESC) AS middle,
         LEAD(rating, 2) OVER (PARTITION BY employee_id ORDER BY review_date DESC, review_id DESC) AS oldest
  FROM performance_reviews
  QUALIFY ROW_NUMBER() OVER (PARTITION BY employee_id ORDER BY review_date DESC, review_id DESC) = 1
)
SELECT e.employee_id, e.name, l.newest - l.oldest AS improvement_score
FROM latest l
JOIN employees e ON e.employee_id = l.employee_id
WHERE l.oldest IS NOT NULL
  AND l.newest > l.middle
  AND l.middle > l.oldest
ORDER BY improvement_score DESC, e.name ASC;
