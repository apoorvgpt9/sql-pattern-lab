-- breaks: edge_typical, edge_exact_1000, edge_overflow_then_light, edge_first_person_only, edge_turn_vs_person_id
-- MISTAKE: SUM(weight) OVER () with no ORDER BY inside the window: every row gets the GRAND total, not a running total.
-- It looks right whenever everyone fits (edge_everyone_fits passes) and returns nothing once the queue overflows.
SELECT person_name
FROM (SELECT person_name, turn, SUM(weight) OVER () AS total_weight FROM Queue) t
WHERE total_weight <= 1000
ORDER BY turn DESC
LIMIT 1;
