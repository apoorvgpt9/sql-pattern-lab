-- Approach 3 (optimal): the same recursion, but the member filter moves INTO the anchor.
-- MySQL does not push an outer WHERE through a recursive CTE, so this is the only way to make the
-- recursion walk just the requested chains. Still "for any member": the anchor's IN list is the parameter.
WITH RECURSIVE recommenders (member, recommender) AS (
  SELECT memid, recommendedby
  FROM members
  WHERE memid IN (12, 22)                    -- the parameter: which members' chains to build
    AND recommendedby IS NOT NULL
  UNION ALL
  SELECT r.member, m.recommendedby
  FROM recommenders r
  JOIN members m ON m.memid = r.recommender
  WHERE m.recommendedby IS NOT NULL
)
SELECT r.member, r.recommender, m.firstname, m.surname
FROM recommenders r
JOIN members m ON m.memid = r.recommender
ORDER BY r.member ASC, r.recommender DESC;
