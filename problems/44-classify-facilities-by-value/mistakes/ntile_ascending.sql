-- breaks: edge_typical, edge_order, edge_uneven_four, edge_two_facilities, edge_revenue_ties
-- MISTAKE: NTILE over revenue ASC. Bucket 1 is then the LOWEST earners, so 'high' and 'low' swap
-- (and with an uneven count the sizes land on the wrong labels too).
WITH rev AS (
  SELECT f.facid, f.name,
         SUM(b.slots * CASE WHEN b.memid = 0 THEN f.guestcost ELSE f.membercost END) AS revenue
  FROM bookings b JOIN facilities f ON f.facid = b.facid
  GROUP BY f.facid, f.name
)
SELECT name, CASE NTILE(3) OVER (ORDER BY revenue ASC, facid) WHEN 1 THEN 'high' WHEN 2 THEN 'average' ELSE 'low' END AS revenue
FROM rev
ORDER BY NTILE(3) OVER (ORDER BY revenue ASC, facid), name;
