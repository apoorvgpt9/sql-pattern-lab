-- breaks: edge_uneven_four, edge_two_facilities
-- MISTAKE: hand-rolled buckets as CEIL(row_number * 3 / n). Correct when n is a multiple of 3, but it
-- gives the extra rows to the LATER buckets (sizes 1, 1, 2 for n = 4; buckets 2 and 3 for n = 2),
-- while NTILE gives them to the earlier ones.
WITH rev AS (
  SELECT f.facid, f.name,
         SUM(b.slots * CASE WHEN b.memid = 0 THEN f.guestcost ELSE f.membercost END) AS revenue
  FROM bookings b JOIN facilities f ON f.facid = b.facid
  GROUP BY f.facid, f.name
),
pos AS (SELECT name, ROW_NUMBER() OVER (ORDER BY revenue DESC, facid) AS rn, COUNT(*) OVER () AS n FROM rev)
SELECT name, CASE CEIL(rn * 3 / n) WHEN 1 THEN 'high' WHEN 2 THEN 'average' ELSE 'low' END AS revenue
FROM pos
ORDER BY CEIL(rn * 3 / n), name;
