-- Approach 3 (optimal): count per role first (each GROUP BY reads one column, and the requester one
-- can follow the primary key), then add the two partial counts per person.
-- The union now carries one row per (person, role) instead of one row per friendship endpoint.
WITH per_role AS (
  SELECT requester_id AS id, COUNT(*) AS n
  FROM RequestAccepted
  GROUP BY requester_id
  UNION ALL
  SELECT accepter_id, COUNT(*)
  FROM RequestAccepted
  GROUP BY accepter_id
)
SELECT id, SUM(n) AS num
FROM per_role
GROUP BY id
ORDER BY num DESC
LIMIT 1;
