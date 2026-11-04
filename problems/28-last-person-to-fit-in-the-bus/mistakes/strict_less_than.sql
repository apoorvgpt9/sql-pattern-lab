-- breaks: edge_exact_1000
-- MISTAKE: 'at most 1000' written as < 1000: the person whose running total is exactly 1000 is rejected.
SELECT person_name
FROM (SELECT person_name, turn,
             SUM(weight) OVER (ORDER BY turn ROWS UNBOUNDED PRECEDING) AS total_weight
      FROM Queue) t
WHERE total_weight < 1000
ORDER BY turn DESC
LIMIT 1;
