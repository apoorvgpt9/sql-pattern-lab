-- breaks: edge_rounding
-- MISTAKE: casting to DOUBLE "to avoid integer division". MySQL's `/` never truncates, and DOUBLE makes
-- ROUND(0.125e0, 2) round the exact binary half to even (0.12) where DECIMAL rounds it up (0.13).
SELECT s.user_id,
       ROUND(COALESCE(CAST(p.n_confirmed AS DOUBLE) / p.n_requests, 0), 2) AS confirmation_rate
FROM Signups s
LEFT JOIN (SELECT user_id, SUM(action = 'confirmed') AS n_confirmed, COUNT(*) AS n_requests
           FROM Confirmations GROUP BY user_id) p ON p.user_id = s.user_id;
