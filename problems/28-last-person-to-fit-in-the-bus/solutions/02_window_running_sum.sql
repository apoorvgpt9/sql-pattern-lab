-- Approach 2: running total with a window function over ALL people, then take the last row that still fits.
-- Because weights are positive the running total only grows, so "fits" holds for a prefix of the queue,
-- and the person with the largest turn among those that fit is the last one who boards.
SELECT person_name
FROM (
  SELECT person_name, turn,
         SUM(weight) OVER (ORDER BY turn ROWS UNBOUNDED PRECEDING) AS total_weight
  FROM Queue
) t
WHERE total_weight <= 1000
ORDER BY turn DESC
LIMIT 1;
