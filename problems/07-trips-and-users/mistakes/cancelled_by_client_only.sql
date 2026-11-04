-- breaks: edge_typical
-- MISTAKE: only 'cancelled_by_client' is treated as a cancellation. "Cancelled by client or driver" means every status
-- other than 'completed'.
SELECT t.request_at AS Day, ROUND(AVG(t.status = 'cancelled_by_client'), 2) AS `Cancellation Rate`
FROM Trips t
JOIN Users c ON c.users_id = t.client_id AND c.banned = 'No'
JOIN Users d ON d.users_id = t.driver_id AND d.banned = 'No'
WHERE t.request_at BETWEEN '2013-10-01' AND '2013-10-03'
GROUP BY t.request_at;
