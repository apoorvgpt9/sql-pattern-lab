-- breaks: edge_typical, edge_order, edge_uneven_four, edge_two_facilities, edge_revenue_ties
-- MISTAKE: sorting by the output column 'revenue' (the label). Text sorts 'average' < 'high' < 'low',
-- so the middle bucket comes first. The spec orders by bucket NUMBER; keep it as a column to sort on.
WITH rev AS (
  SELECT f.facid, f.name,
         SUM(b.slots * CASE WHEN b.memid = 0 THEN f.guestcost ELSE f.membercost END) AS revenue
  FROM bookings b JOIN facilities f ON f.facid = b.facid
  GROUP BY f.facid, f.name
)
SELECT name, CASE NTILE(3) OVER (ORDER BY revenue DESC, facid) WHEN 1 THEN 'high' WHEN 2 THEN 'average' ELSE 'low' END AS revenue
FROM rev
ORDER BY revenue, name;
