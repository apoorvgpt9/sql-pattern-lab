-- breaks: edge_everyone_fits
-- MISTAKE: Finding the first overflow row and stepping back one (LAG). Correct whenever somebody overflows; but if everyone fits
-- there is no overflow row, so the query returns nothing instead of the last person.
SELECT prev_name AS person_name
FROM (SELECT turn,
             SUM(weight) OVER (ORDER BY turn ROWS UNBOUNDED PRECEDING) AS total_weight,
             LAG(person_name) OVER (ORDER BY turn) AS prev_name
      FROM Queue) t
WHERE total_weight > 1000
ORDER BY turn ASC
LIMIT 1;
