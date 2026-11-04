-- UNVERIFIED: Snowflake version of the optimal approach (03). CI cannot run Snowflake.
-- Differences are noted in README section 9. Tie-break on equal revenue: facid ASC (README "Assumptions").
WITH slot_totals AS (
  SELECT facid,
         SUM(IFF(memid = 0, slots, 0)) AS guest_slots,
         SUM(IFF(memid = 0, 0, slots)) AS member_slots
  FROM bookings
  GROUP BY facid
)
SELECT f.name,
       DECODE(NTILE(3) OVER (ORDER BY s.guest_slots * f.guestcost + s.member_slots * f.membercost DESC,
                                      f.facid ASC),
              1, 'high', 2, 'average', 'low') AS revenue
FROM slot_totals s
JOIN facilities f ON f.facid = s.facid
ORDER BY NTILE(3) OVER (ORDER BY s.guest_slots * f.guestcost + s.member_slots * f.membercost DESC,
                                 f.facid ASC),
         f.name;
