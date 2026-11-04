-- Approach 1 (brute force): rank each review by counting how many reviews of the same employee are newer,
-- then self-join the rank-1, rank-2 and rank-3 reviews and compare their ratings. No window functions.
-- "Newer" = later review_date, or the same date with a larger review_id (tie-break, see README Assumptions).
WITH ranked AS (
  SELECT r.employee_id, r.rating,
         1 + (SELECT COUNT(*)
                FROM performance_reviews x
               WHERE x.employee_id = r.employee_id
                 AND (x.review_date > r.review_date
                      OR (x.review_date = r.review_date AND x.review_id > r.review_id))) AS rn
  FROM performance_reviews r
)
SELECT e.employee_id, e.name, r1.rating - r3.rating AS improvement_score
FROM employees e
JOIN ranked r1 ON r1.employee_id = e.employee_id AND r1.rn = 1
JOIN ranked r2 ON r2.employee_id = e.employee_id AND r2.rn = 2
JOIN ranked r3 ON r3.employee_id = e.employee_id AND r3.rn = 3
WHERE r1.rating > r2.rating
  AND r2.rating > r3.rating
ORDER BY improvement_score DESC, e.name ASC;
