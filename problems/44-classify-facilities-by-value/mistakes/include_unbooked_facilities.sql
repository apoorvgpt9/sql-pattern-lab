-- breaks: edge_typical, edge_no_bookings
-- MISTAKE: driving from facilities with a LEFT JOIN "so nothing is lost". Unbooked facilities get
-- revenue NULL, join the ranking (NULL sorts last in DESC), and change every bucket's size.
WITH rev AS (
  SELECT f.facid, f.name,
         SUM(b.slots * CASE WHEN b.memid = 0 THEN f.guestcost ELSE f.membercost END) AS revenue
  FROM facilities f LEFT JOIN bookings b ON b.facid = f.facid
  GROUP BY f.facid, f.name
)
SELECT name, CASE NTILE(3) OVER (ORDER BY revenue DESC, facid) WHEN 1 THEN 'high' WHEN 2 THEN 'average' ELSE 'low' END AS revenue
FROM rev
ORDER BY NTILE(3) OVER (ORDER BY revenue DESC, facid), name;
