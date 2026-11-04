-- breaks: edge_typical, edge_window_boundaries, edge_member_vs_guest, edge_ordering
-- MISTAKE: Comparing starttime (a DATETIME) with the date itself: starttime <= a.day means 'at or before midnight', so every booking
-- made later on the day is lost. The window must end before the NEXT midnight.
WITH RECURSIVE august AS (
  SELECT DATE '2012-08-01' AS day
  UNION ALL
  SELECT day + INTERVAL 1 DAY FROM august WHERE day < DATE '2012-08-31'
)
SELECT a.day AS `date`,
       (SELECT COALESCE(SUM(b.slots * CASE WHEN b.memid = 0 THEN f.guestcost ELSE f.membercost END), 0)
          FROM bookings b JOIN facilities f ON f.facid = b.facid
         WHERE b.starttime >= a.day - INTERVAL 14 DAY
           AND b.starttime <= a.day) / 15 AS revenue
FROM august a
ORDER BY a.day;
