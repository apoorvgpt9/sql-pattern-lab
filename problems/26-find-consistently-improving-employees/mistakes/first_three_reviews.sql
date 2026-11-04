-- breaks: edge_last_three_only
-- MISTAKE: ordering ASC takes the OLDEST three reviews instead of the most recent three. With exactly
-- three reviews per employee it looks right; with longer histories it tests the wrong reviews.
WITH early AS (
  SELECT employee_id, rating,
         ROW_NUMBER() OVER (PARTITION BY employee_id ORDER BY review_date ASC, review_id ASC) AS rn
  FROM performance_reviews
),
first3 AS (
  SELECT employee_id,
         COUNT(*) AS n,
         MAX(CASE WHEN rn = 1 THEN rating END) AS oldest,
         MAX(CASE WHEN rn = 2 THEN rating END) AS middle,
         MAX(CASE WHEN rn = 3 THEN rating END) AS newest
  FROM early WHERE rn <= 3 GROUP BY employee_id
)
SELECT e.employee_id, e.name, f.newest - f.oldest AS improvement_score
FROM first3 f JOIN employees e ON e.employee_id = f.employee_id
WHERE f.n = 3 AND f.newest > f.middle AND f.middle > f.oldest
ORDER BY improvement_score DESC, e.name ASC;
