-- breaks: edge_same_date
-- MISTAKE: tie-break on review_id in the opposite direction to the date. Newest-first by date needs newest-first by id too;
-- (review_date DESC, review_id ASC) puts the OLDER of two same-day reviews first.
WITH latest AS (
  SELECT employee_id, rating AS newest,
         LEAD(rating, 1) OVER w AS middle, LEAD(rating, 2) OVER w AS oldest,
         ROW_NUMBER() OVER w AS rn
  FROM performance_reviews
  WINDOW w AS (PARTITION BY employee_id ORDER BY review_date DESC, review_id ASC)
)
SELECT e.employee_id, e.name, l.newest - l.oldest AS improvement_score
FROM latest l JOIN employees e ON e.employee_id = l.employee_id
WHERE l.rn = 1 AND l.oldest IS NOT NULL AND l.newest > l.middle AND l.middle > l.oldest
ORDER BY improvement_score DESC, e.name ASC;
