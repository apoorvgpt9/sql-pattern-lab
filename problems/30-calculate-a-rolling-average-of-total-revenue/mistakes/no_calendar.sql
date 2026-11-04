-- breaks: edge_typical, edge_window_boundaries, edge_member_vs_guest, edge_no_bookings, edge_ordering
-- MISTAKE: No calendar: the window runs over only the days that HAVE bookings. Quiet days are missing from the output, and
-- '14 rows before' reaches back much further than 14 days.
WITH booked AS (
  SELECT DATE(b.starttime) AS day, SUM(b.slots * CASE WHEN b.memid = 0 THEN f.guestcost ELSE f.membercost END) AS revenue
  FROM bookings b JOIN facilities f ON f.facid = b.facid
  WHERE b.starttime >= '2012-07-18' AND b.starttime < '2012-09-01'
  GROUP BY DATE(b.starttime)
),
windowed AS (
  SELECT day, SUM(revenue) OVER (ORDER BY day ROWS BETWEEN 14 PRECEDING AND CURRENT ROW) AS window_total FROM booked
)
SELECT day AS `date`, window_total / 15 AS revenue
FROM windowed WHERE day >= DATE '2012-08-01'
ORDER BY day;
