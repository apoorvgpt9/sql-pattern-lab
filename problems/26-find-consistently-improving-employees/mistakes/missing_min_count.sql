-- breaks: edge_fewer_than_three
-- MISTAKE: no "at least 3 reviews" guard. With 2 reviews LEAD(2) is NULL; this version treats a missing
-- third review as "nothing to compare" and lets the employee through using the two reviews they have.
WITH latest AS (
  SELECT employee_id, rating AS newest,
         LEAD(rating, 1) OVER w AS middle, LEAD(rating, 2) OVER w AS oldest,
         ROW_NUMBER() OVER w AS rn
  FROM performance_reviews
  WINDOW w AS (PARTITION BY employee_id ORDER BY review_date DESC, review_id DESC)
)
SELECT e.employee_id, e.name, l.newest - COALESCE(l.oldest, l.middle) AS improvement_score
FROM latest l JOIN employees e ON e.employee_id = l.employee_id
WHERE l.rn = 1 AND l.middle IS NOT NULL AND l.newest > l.middle
  AND (l.oldest IS NULL OR l.middle > l.oldest)
ORDER BY improvement_score DESC, e.name ASC;
