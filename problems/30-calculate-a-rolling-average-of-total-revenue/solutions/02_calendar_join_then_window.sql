-- Approach 2: build a calendar from 14 days before August to the end of August, LEFT JOIN every booking onto its
-- date (join first), group to one row per calendar day (0 where nothing was booked), then a 15-row window sums
-- the day and the 14 rows before it. The calendar has no gaps, so a ROWS frame equals a 15-day frame.
WITH RECURSIVE calendar AS (
  SELECT DATE '2012-07-18' AS day
  UNION ALL
  SELECT day + INTERVAL 1 DAY FROM calendar WHERE day < DATE '2012-08-31'
),
daily AS (
  SELECT c.day,
         COALESCE(SUM(b.slots * CASE WHEN b.memid = 0 THEN f.guestcost ELSE f.membercost END), 0) AS revenue
  FROM calendar c
  LEFT JOIN bookings   b ON DATE(b.starttime) = c.day
  LEFT JOIN facilities f ON f.facid = b.facid
  GROUP BY c.day
),
windowed AS (
  SELECT day,
         SUM(revenue) OVER (ORDER BY day ROWS BETWEEN 14 PRECEDING AND CURRENT ROW) AS window_total
  FROM daily
)
SELECT day AS `date`, window_total / 15 AS revenue
FROM windowed
WHERE day >= DATE '2012-08-01'
ORDER BY day;
