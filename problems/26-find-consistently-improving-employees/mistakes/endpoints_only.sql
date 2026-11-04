-- breaks: edge_typical, edge_equal_ratings, edge_last_three_only
-- MISTAKE: comparing only the newest and the oldest of the three. A dip or a flat step in the middle is missed.
WITH latest AS (
  SELECT employee_id, rating AS newest,
         LEAD(rating, 2) OVER w AS oldest,
         ROW_NUMBER() OVER w AS rn
  FROM performance_reviews
  WINDOW w AS (PARTITION BY employee_id ORDER BY review_date DESC, review_id DESC)
)
SELECT e.employee_id, e.name, l.newest - l.oldest AS improvement_score
FROM latest l JOIN employees e ON e.employee_id = l.employee_id
WHERE l.rn = 1 AND l.oldest IS NOT NULL AND l.newest > l.oldest
ORDER BY improvement_score DESC, e.name ASC;
