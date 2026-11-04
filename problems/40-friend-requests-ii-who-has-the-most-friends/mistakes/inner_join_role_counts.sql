-- breaks: edge_accepter_only, edge_requester_only
-- MISTAKE: count each role separately (good), then combine with an INNER JOIN (bad). MySQL has no
-- FULL OUTER JOIN, and an inner join keeps only people who appear in BOTH roles, so a winner who
-- only accepted (or only requested) disappears. edge_typical passes: its winner has both roles.
WITH r AS (SELECT requester_id AS id, COUNT(*) AS n FROM RequestAccepted GROUP BY requester_id),
     a AS (SELECT accepter_id  AS id, COUNT(*) AS n FROM RequestAccepted GROUP BY accepter_id)
SELECT r.id, r.n + a.n AS num
FROM r
JOIN a ON a.id = r.id
ORDER BY num DESC
LIMIT 1;
