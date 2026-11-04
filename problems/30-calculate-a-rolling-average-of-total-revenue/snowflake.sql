-- UNVERIFIED: Snowflake version of the optimal approach (03). CI cannot run Snowflake.
-- Differences from MySQL (README section 9): the calendar comes from GENERATOR instead of a recursive CTE,
-- IFF replaces CASE, and ::DATE replaces DATE().
WITH calendar AS (
  SELECT DATEADD(day, ROW_NUMBER() OVER (ORDER BY SEQ4()) - 1, DATE '2012-07-18') AS day
  FROM TABLE(GENERATOR(ROWCOUNT => 45))          -- 2012-07-18 .. 2012-08-31
),
booked AS (
  SELECT b.starttime::DATE AS day,
         SUM(b.slots * IFF(b.memid = 0, f.guestcost, f.membercost)) AS revenue
  FROM bookings b
  JOIN facilities f ON f.facid = b.facid
  WHERE b.starttime >= '2012-07-18'              -- raw-column range: the form micro-partition pruning can use
    AND b.starttime <  '2012-09-01'
  GROUP BY 1
),
windowed AS (
  SELECT c.day,
         SUM(COALESCE(k.revenue, 0)) OVER (ORDER BY c.day ROWS BETWEEN 14 PRECEDING AND CURRENT ROW) AS window_total
  FROM calendar c
  LEFT JOIN booked k ON k.day = c.day
)
SELECT day AS date, window_total / 15 AS revenue
FROM windowed
WHERE day >= DATE '2012-08-01'
ORDER BY day;
