-- Approach 1 (brute force): for each August date, sum the revenue of every booking in the 15-day interval
-- ending that day with a correlated subquery, then divide by 15. A day with no bookings in its window
-- gets NULL from SUM, so COALESCE makes it 0. The August dates come from a recursive CTE (MySQL has no generate_series).
WITH RECURSIVE august AS (
  SELECT DATE '2012-08-01' AS day
  UNION ALL
  SELECT day + INTERVAL 1 DAY FROM august WHERE day < DATE '2012-08-31'
)
SELECT a.day AS `date`,
       (SELECT COALESCE(SUM(b.slots * CASE WHEN b.memid = 0 THEN f.guestcost ELSE f.membercost END), 0)
          FROM bookings b
          JOIN facilities f ON f.facid = b.facid
         WHERE b.starttime >= a.day - INTERVAL 14 DAY
           AND b.starttime <  a.day + INTERVAL 1 DAY) / 15 AS revenue
FROM august a
ORDER BY a.day;
