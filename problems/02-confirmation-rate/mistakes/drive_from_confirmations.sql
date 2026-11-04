-- breaks: edge_typical, edge_no_confirmations, edge_orphan_confirmations, edge_empty_signups
-- MISTAKE: group Confirmations alone. Users with no requests are absent, and users who are not in
-- Signups appear. The grain of the answer is Signups, not "anyone who made a request".
SELECT user_id, ROUND(AVG(action = 'confirmed'), 2) AS confirmation_rate
FROM Confirmations
GROUP BY user_id;
