-- breaks: edge_typical, edge_accepter_only, edge_runner_up_ties
-- MISTAKE: friendship is symmetric, but this counts only the rows where the person sent the request.
-- It passes edge_requester_only, where the winner never accepted anything: a dataset whose winner
-- happens to be a pure requester cannot catch this, which is why edge_typical mixes both roles.
SELECT requester_id AS id, COUNT(*) AS num
FROM RequestAccepted
GROUP BY requester_id
ORDER BY num DESC
LIMIT 1;
