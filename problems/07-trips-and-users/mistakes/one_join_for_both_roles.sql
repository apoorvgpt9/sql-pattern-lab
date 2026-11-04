-- breaks: edge_typical
-- MISTAKE: one join to Users for both roles: u.users_id IN (client_id, driver_id). Each trip now yields one row per unbanned party,
-- not one row per trip: a trip with two unbanned parties is counted twice and a trip with one banned party still gets one row
-- (it should be dropped). Fan-out and leakage at the same time.
SELECT t.request_at AS Day, ROUND(AVG(t.status <> 'completed'), 2) AS `Cancellation Rate`
FROM Trips t
JOIN Users u ON u.users_id IN (t.client_id, t.driver_id) AND u.banned = 'No'
WHERE t.request_at BETWEEN '2013-10-01' AND '2013-10-03'
GROUP BY t.request_at;
