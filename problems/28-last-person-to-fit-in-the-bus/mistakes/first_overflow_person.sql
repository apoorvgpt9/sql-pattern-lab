-- breaks: edge_typical, edge_exact_1000, edge_overflow_then_light, edge_first_person_only, edge_everyone_fits
-- MISTAKE: Off by one: returning the first person who does NOT fit (the one whose running total first exceeds 1000)
-- instead of the person before them. When nobody overflows it returns nothing at all.
SELECT person_name
FROM (SELECT person_name, turn,
             SUM(weight) OVER (ORDER BY turn ROWS UNBOUNDED PRECEDING) AS total_weight
      FROM Queue) t
WHERE total_weight > 1000
ORDER BY turn ASC
LIMIT 1;
