-- Approach 1 (brute force, no window functions): compute each facility's position in the revenue
-- ranking with a correlated COUNT, then turn the position into a bucket with integer arithmetic.
-- Natural first attempt for anyone who learned SQL before window functions.
-- Tie-break on equal revenue: facid ASC (README "Assumptions").
-- For 3 buckets, ((position - 1) * 3) DIV n + 1 gives exactly NTILE(3)'s sizes (proof in README 5).
WITH rev AS (
  SELECT f.facid, f.name,
         SUM(b.slots * CASE WHEN b.memid = 0 THEN f.guestcost ELSE f.membercost END) AS revenue
  FROM bookings b
  JOIN facilities f ON f.facid = b.facid
  GROUP BY f.facid, f.name
),
pos AS (
  SELECT r.name,
         1 + (SELECT COUNT(*) FROM rev o
               WHERE o.revenue > r.revenue
                  OR (o.revenue = r.revenue AND o.facid < r.facid)) AS position,
         (SELECT COUNT(*) FROM rev) AS n
  FROM rev r
)
SELECT name,
       CASE ((position - 1) * 3) DIV n
         WHEN 0 THEN 'high'
         WHEN 1 THEN 'average'
         ELSE 'low'
       END AS revenue
FROM pos
ORDER BY ((position - 1) * 3) DIV n, name;
