-- Approach 2: join Users twice (once as the client, once as the driver), keep only unbanned on both sides,
-- filter the date range, group by day. AVG over a 0/1 comparison is the cancelled share.
SELECT t.request_at AS Day,
       ROUND(AVG(t.status <> 'completed'), 2) AS `Cancellation Rate`
FROM Trips t
JOIN Users c ON c.users_id = t.client_id AND c.banned = 'No'
JOIN Users d ON d.users_id = t.driver_id AND d.banned = 'No'
WHERE t.request_at BETWEEN '2013-10-01' AND '2013-10-03'
GROUP BY t.request_at;
