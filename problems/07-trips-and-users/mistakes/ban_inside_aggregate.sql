-- breaks: edge_banned_day_absent
-- MISTAKE: handle the ban inside the aggregate instead of as a filter. Every trip stays in the groups, so a day with no
-- eligible trip is still a group, and its rate is 0 / 0 = NULL: the day appears with a NULL instead of being absent.
SELECT t.request_at AS Day,
       ROUND(SUM(t.status <> 'completed' AND c.banned = 'No' AND d.banned = 'No')
           / SUM(c.banned = 'No' AND d.banned = 'No'), 2) AS `Cancellation Rate`
FROM Trips t
JOIN Users c ON c.users_id = t.client_id
JOIN Users d ON d.users_id = t.driver_id
WHERE t.request_at BETWEEN '2013-10-01' AND '2013-10-03'
GROUP BY t.request_at;
