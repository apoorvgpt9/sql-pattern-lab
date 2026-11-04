-- Approach 3 (optimal): reduce the bookings first, then attach the result to the calendar.
--  1. only bookings in [2012-07-18, 2012-09-01) matter: a range on the raw column, usable by an index on starttime;
--  2. aggregate them to one revenue figure per day;
--  3. LEFT JOIN that small result onto the calendar (zero-fill), then the 15-row window.
WITH RECURSIVE calendar AS (
  SELECT DATE '2012-07-18' AS day
  UNION ALL
  SELECT day + INTERVAL 1 DAY FROM calendar WHERE day < DATE '2012-08-31'
),
booked AS (
  SELECT DATE(b.starttime) AS day,
         SUM(b.slots * CASE WHEN b.memid = 0 THEN f.guestcost ELSE f.membercost END) AS revenue
  FROM bookings b
  JOIN facilities f ON f.facid = b.facid
  WHERE b.starttime >= '2012-07-18'
    AND b.starttime <  '2012-09-01'
  GROUP BY DATE(b.starttime)
),
daily AS (
  SELECT c.day, COALESCE(k.revenue, 0) AS revenue
  FROM calendar c
  LEFT JOIN booked k ON k.day = c.day
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
