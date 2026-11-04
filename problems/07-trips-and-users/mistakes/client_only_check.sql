-- breaks: edge_typical
-- MISTAKE: only the client is checked for a ban. A trip with an unbanned client and a banned driver (trip 3) leaks in.
SELECT t.request_at AS Day, ROUND(AVG(t.status <> 'completed'), 2) AS `Cancellation Rate`
FROM Trips t
JOIN Users c ON c.users_id = t.client_id AND c.banned = 'No'
WHERE t.request_at BETWEEN '2013-10-01' AND '2013-10-03'
GROUP BY t.request_at;
