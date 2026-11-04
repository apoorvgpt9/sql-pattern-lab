-- breaks: edge_typical, edge_no_confirmations, edge_rounding
-- MISTAKE: "confirmed" is filtered in WHERE. That deletes the timeout rows (so the denominator is wrong:
-- every surviving user gets 1.00) and deletes every user with no confirmed row (they vanish).
SELECT s.user_id, ROUND(COUNT(c.action) / COUNT(c.action), 2) AS confirmation_rate
FROM Signups s
LEFT JOIN Confirmations c ON c.user_id = s.user_id
WHERE c.action = 'confirmed'
GROUP BY s.user_id;
