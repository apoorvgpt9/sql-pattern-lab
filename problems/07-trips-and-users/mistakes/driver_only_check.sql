-- breaks: edge_typical
-- MISTAKE: only the driver is checked for a ban. A trip with a banned client and an unbanned driver (trip 2) leaks in.
SELECT t.request_at AS Day, ROUND(AVG(t.status <> 'completed'), 2) AS `Cancellation Rate`
FROM Trips t
JOIN Users d ON d.users_id = t.driver_id AND d.banned = 'No'
WHERE t.request_at BETWEEN '2013-10-01' AND '2013-10-03'
GROUP BY t.request_at;
