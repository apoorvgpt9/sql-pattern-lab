-- Approach 2: ROW_NUMBER keeps the 3 most recent reviews per employee, conditional aggregation turns
-- those 3 rows into one row (newest / middle / oldest), and the comparison runs on that row.
-- COUNT(*) = 3 is the "at least 3 reviews" rule: fewer than 3 rows can never fill all three slots.
WITH ranked AS (
  SELECT employee_id, rating,
         ROW_NUMBER() OVER (PARTITION BY employee_id ORDER BY review_date DESC, review_id DESC) AS rn
  FROM performance_reviews
),
last3 AS (
  SELECT employee_id,
         COUNT(*)                                   AS n,
         MAX(CASE WHEN rn = 1 THEN rating END)      AS newest,
         MAX(CASE WHEN rn = 2 THEN rating END)      AS middle,
         MAX(CASE WHEN rn = 3 THEN rating END)      AS oldest
  FROM ranked
  WHERE rn <= 3
  GROUP BY employee_id
)
SELECT e.employee_id, e.name, l.newest - l.oldest AS improvement_score
FROM last3 l
JOIN employees e ON e.employee_id = l.employee_id
WHERE l.n = 3
  AND l.newest > l.middle
  AND l.middle > l.oldest
ORDER BY improvement_score DESC, e.name ASC;
