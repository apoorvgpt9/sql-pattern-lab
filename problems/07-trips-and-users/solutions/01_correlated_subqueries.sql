-- Approach 1 (brute force): list the days in range, then for each day count the eligible trips and the eligible
-- cancelled trips with correlated subqueries. "Eligible" = client and driver both exist and are not banned,
-- written as membership in the set of unbanned users.
SELECT d.request_at AS Day,
       ROUND(
         (SELECT COUNT(*) FROM Trips t
           WHERE t.request_at = d.request_at AND t.status <> 'completed'
             AND t.client_id IN (SELECT users_id FROM Users WHERE banned = 'No')
             AND t.driver_id IN (SELECT users_id FROM Users WHERE banned = 'No'))
         /
         (SELECT COUNT(*) FROM Trips t
           WHERE t.request_at = d.request_at
             AND t.client_id IN (SELECT users_id FROM Users WHERE banned = 'No')
             AND t.driver_id IN (SELECT users_id FROM Users WHERE banned = 'No')), 2) AS `Cancellation Rate`
FROM (SELECT DISTINCT request_at FROM Trips WHERE request_at BETWEEN '2013-10-01' AND '2013-10-03') d
WHERE (SELECT COUNT(*) FROM Trips t
        WHERE t.request_at = d.request_at
          AND t.client_id IN (SELECT users_id FROM Users WHERE banned = 'No')
          AND t.driver_id IN (SELECT users_id FROM Users WHERE banned = 'No')) > 0;
