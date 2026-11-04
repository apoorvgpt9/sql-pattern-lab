-- Approach 2: one window pass, newest review first. On each review, LEAD(1) and LEAD(2) read
-- the next-older and the second-next-older ratings, so the newest row of each employee already holds all three
-- ratings. Keep only that row (rn = 1). If the employee has fewer than 3 reviews, LEAD(2) is NULL and the row is dropped.
-- The clearest single-pass form, but MySQL must buffer rows to look ahead (EXPLAIN: "Window aggregate with buffering")
-- and evaluates the window for every review, including the ones that will be discarded.
WITH latest AS (
  SELECT employee_id,
         rating                  AS newest,
         LEAD(rating, 1) OVER w  AS middle,
         LEAD(rating, 2) OVER w  AS oldest,
         ROW_NUMBER()    OVER w  AS rn
  FROM performance_reviews
  WINDOW w AS (PARTITION BY employee_id ORDER BY review_date DESC, review_id DESC)
)
SELECT e.employee_id, e.name, l.newest - l.oldest AS improvement_score
FROM latest l
JOIN employees e ON e.employee_id = l.employee_id
WHERE l.rn = 1
  AND l.oldest IS NOT NULL
  AND l.newest > l.middle
  AND l.middle > l.oldest
ORDER BY improvement_score DESC, e.name ASC;
