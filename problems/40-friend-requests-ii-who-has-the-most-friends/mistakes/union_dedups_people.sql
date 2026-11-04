-- breaks: edge_typical, edge_accepter_only, edge_runner_up_ties, edge_requester_only
-- MISTAKE: UNION instead of UNION ALL. The union of two id columns is a set of people, so every
-- person appears once and every count is 1. The query still returns one row, which hides the bug.
SELECT id, COUNT(*) AS num
FROM (
  SELECT requester_id AS id FROM RequestAccepted
  UNION
  SELECT accepter_id FROM RequestAccepted
) t
GROUP BY id
ORDER BY num DESC
LIMIT 1;
