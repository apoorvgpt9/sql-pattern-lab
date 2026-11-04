-- Approach 2: join every booking to its facility, price it, sum per facility, then NTILE(3).
-- The window runs after GROUP BY, over one row per facility.
WITH rev AS (
  SELECT f.facid, f.name,
         SUM(b.slots * CASE WHEN b.memid = 0 THEN f.guestcost ELSE f.membercost END) AS revenue
  FROM bookings b
  JOIN facilities f ON f.facid = b.facid
  GROUP BY f.facid, f.name
),
bucketed AS (
  SELECT name, NTILE(3) OVER (ORDER BY revenue DESC, facid ASC) AS bucket
  FROM rev
)
SELECT name,
       CASE bucket WHEN 1 THEN 'high' WHEN 2 THEN 'average' ELSE 'low' END AS revenue
FROM bucketed
ORDER BY bucket, name;
