-- breaks: edge_typical, edge_banned_day_absent
-- MISTAKE: "neither is banned" turned into "at least one is unbanned" (the ban test OR'd instead of AND'd): a trip is dropped
-- only when BOTH parties are banned.
SELECT t.request_at AS Day, ROUND(AVG(t.status <> 'completed'), 2) AS `Cancellation Rate`
FROM Trips t
JOIN Users c ON c.users_id = t.client_id
JOIN Users d ON d.users_id = t.driver_id
WHERE (c.banned = 'No' OR d.banned = 'No')
  AND t.request_at BETWEEN '2013-10-01' AND '2013-10-03'
GROUP BY t.request_at;
