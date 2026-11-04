-- breaks: edge_date_boundaries
-- MISTAKE: the range written as >= start AND < end. "From 2013-10-01 to 2013-10-03 inclusive" includes the 3rd.
SELECT t.request_at AS Day, ROUND(AVG(t.status <> 'completed'), 2) AS `Cancellation Rate`
FROM Trips t
JOIN Users c ON c.users_id = t.client_id AND c.banned = 'No'
JOIN Users d ON d.users_id = t.driver_id AND d.banned = 'No'
WHERE t.request_at >= '2013-10-01' AND t.request_at < '2013-10-03'
GROUP BY t.request_at;
