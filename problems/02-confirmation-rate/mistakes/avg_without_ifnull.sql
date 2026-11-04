-- breaks: edge_typical, edge_no_confirmations, edge_rounding
-- MISTAKE: correct LEFT JOIN, but AVG over a user's single all-NULL row is NULL, not 0.
-- (NULL = 'confirmed' is NULL, AVG skips NULLs, and AVG of nothing is NULL.)
SELECT s.user_id, ROUND(AVG(c.action = 'confirmed'), 2) AS confirmation_rate
FROM Signups s
LEFT JOIN Confirmations c ON c.user_id = s.user_id
GROUP BY s.user_id;
