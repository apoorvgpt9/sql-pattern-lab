-- breaks: edge_turn_vs_person_id
-- MISTAKE: Accumulating in person_id order instead of turn order. person_id is only a key; the boarding order is turn.
SELECT person_name
FROM (SELECT person_name, person_id,
             SUM(weight) OVER (ORDER BY person_id ROWS UNBOUNDED PRECEDING) AS total_weight
      FROM Queue) t
WHERE total_weight <= 1000
ORDER BY person_id DESC
LIMIT 1;
