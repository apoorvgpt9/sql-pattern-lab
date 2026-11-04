-- Approach 3 (optimal): aggregate the big table first - guest slots and member slots per facility -
-- then price once per facility. The join touches one row per facility instead of one per booking,
-- and SUM(slots) * cost = SUM(slots * cost) exactly in DECIMAL arithmetic.
WITH slot_totals AS (
  SELECT facid,
         SUM(CASE WHEN memid = 0 THEN slots ELSE 0 END) AS guest_slots,
         SUM(CASE WHEN memid = 0 THEN 0 ELSE slots END) AS member_slots
  FROM bookings
  GROUP BY facid
),
rev AS (
  SELECT f.facid, f.name,
         s.guest_slots * f.guestcost + s.member_slots * f.membercost AS revenue
  FROM slot_totals s
  JOIN facilities f ON f.facid = s.facid
),
bucketed AS (
  SELECT name, NTILE(3) OVER (ORDER BY revenue DESC, facid ASC) AS bucket
  FROM rev
)
SELECT name,
       CASE bucket WHEN 1 THEN 'high' WHEN 2 THEN 'average' ELSE 'low' END AS revenue
FROM bucketed
ORDER BY bucket, name;
