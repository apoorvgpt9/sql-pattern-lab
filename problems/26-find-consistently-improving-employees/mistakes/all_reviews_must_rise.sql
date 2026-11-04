-- breaks: edge_last_three_only
-- MISTAKE: requiring the WHOLE history to rise ("consistently improving") instead of only the last three reviews.
-- Employees with an old dip but a good recent streak are wrongly rejected.
WITH w AS (
  SELECT employee_id, rating,
         LAG(rating) OVER (PARTITION BY employee_id ORDER BY review_date, review_id)      AS prev,
         ROW_NUMBER() OVER (PARTITION BY employee_id ORDER BY review_date DESC, review_id DESC) AS rn,
         COUNT(*) OVER (PARTITION BY employee_id)                                         AS n
  FROM performance_reviews
)
SELECT e.employee_id, e.name,
       MAX(CASE WHEN w.rn = 1 THEN w.rating END) - MAX(CASE WHEN w.rn = 3 THEN w.rating END) AS improvement_score
FROM w JOIN employees e ON e.employee_id = w.employee_id
GROUP BY e.employee_id, e.name, w.n
HAVING w.n >= 3 AND MIN(w.prev IS NULL OR w.rating > w.prev) = 1
ORDER BY improvement_score DESC, e.name ASC;
