-- breaks: edge_typical
-- MISTAKE: pricing every booking at membercost. Guests (memid 0) pay guestcost; ignoring that
-- reorders facilities whose income is mostly guests (Climbing Wall drops from 32 to 0).
WITH rev AS (
  SELECT f.facid, f.name, SUM(b.slots * f.membercost) AS revenue
  FROM bookings b JOIN facilities f ON f.facid = b.facid
  GROUP BY f.facid, f.name
)
SELECT name, CASE NTILE(3) OVER (ORDER BY revenue DESC, facid) WHEN 1 THEN 'high' WHEN 2 THEN 'average' ELSE 'low' END AS revenue
FROM rev
ORDER BY NTILE(3) OVER (ORDER BY revenue DESC, facid), name;
