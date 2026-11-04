-- breaks: edge_revenue_ties
-- MISTAKE: bucketing on RANK() so that equal revenues share a bucket. It sounds fairer, but the spec
-- asks for groups of as-equal-as-possible size (NTILE semantics): with a tie at the boundary both
-- facilities land in 'high' and the bucket sizes become 3, 0, 1.
WITH rev AS (
  SELECT f.facid, f.name,
         SUM(b.slots * CASE WHEN b.memid = 0 THEN f.guestcost ELSE f.membercost END) AS revenue
  FROM bookings b JOIN facilities f ON f.facid = b.facid
  GROUP BY f.facid, f.name
),
pos AS (SELECT name, RANK() OVER (ORDER BY revenue DESC) AS rk, COUNT(*) OVER () AS n FROM rev)
SELECT name, CASE ((rk - 1) * 3) DIV n WHEN 0 THEN 'high' WHEN 1 THEN 'average' ELSE 'low' END AS revenue
FROM pos
ORDER BY ((rk - 1) * 3) DIV n, name;
