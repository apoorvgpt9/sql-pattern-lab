-- breaks: edge_typical, edge_no_confirmations, edge_rounding
-- MISTAKE: INNER JOIN. "Each user" needs every signup to survive; users with no requests disappear.
SELECT s.user_id, ROUND(AVG(c.action = 'confirmed'), 2) AS confirmation_rate
FROM Signups s
JOIN Confirmations c ON c.user_id = s.user_id
GROUP BY s.user_id;
