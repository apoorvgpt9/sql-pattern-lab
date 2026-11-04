-- breaks: edge_rounding
-- MISTAKE: casting to DOUBLE "to avoid integer division" (MySQL's / never truncates). ROUND on a DOUBLE rounds an exactly
-- representable half to even: 0.125 -> 0.12, where DECIMAL gives 0.13.
SELECT t.request_at AS Day,
       ROUND(CAST(SUM(t.status <> 'completed') AS DOUBLE) / COUNT(*), 2) AS `Cancellation Rate`
FROM Trips t
JOIN Users c ON c.users_id = t.client_id AND c.banned = 'No'
JOIN Users d ON d.users_id = t.driver_id AND d.banned = 'No'
WHERE t.request_at BETWEEN '2013-10-01' AND '2013-10-03'
GROUP BY t.request_at;
