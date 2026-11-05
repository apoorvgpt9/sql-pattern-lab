-- breaks: edge_orphan_users
-- MISTAKE: exclude trips whose client or driver is in the set of BANNED users, instead of requiring them to be in the set of
-- unbanned ones. A trip referencing a user who is not in Users at all is never "in the banned list", so it slips through.
-- Under the original's foreign-key guarantee this query is correct; it is "wrong" only against this repo's pinned choice
-- for orphan trips (README Assumption 1). It is kept to make the two readings visibly different, not as a bad habit.
SELECT request_at AS Day, ROUND(AVG(status <> 'completed'), 2) AS `Cancellation Rate`
FROM Trips
WHERE request_at BETWEEN '2013-10-01' AND '2013-10-03'
  AND client_id NOT IN (SELECT users_id FROM Users WHERE banned = 'Yes')
  AND driver_id NOT IN (SELECT users_id FROM Users WHERE banned = 'Yes')
GROUP BY request_at;
