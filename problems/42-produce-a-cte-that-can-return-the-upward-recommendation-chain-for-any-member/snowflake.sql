-- UNVERIFIED: Snowflake version of the optimal approach (03). CI cannot run Snowflake.
-- Differences are noted in README section 9. CONNECT BY is the shorter alternative (commented below).
WITH RECURSIVE recommenders (member, recommender) AS (
  SELECT memid, recommendedby
  FROM members
  WHERE memid IN (12, 22)
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

-- CONNECT BY form: walk up from each start member; CONNECT_BY_ROOT carries the start member.
-- SELECT CONNECT_BY_ROOT memid AS member, memid AS recommender, firstname, surname
-- FROM members
-- WHERE LEVEL > 1                                  -- drop the start member itself
-- START WITH memid IN (12, 22)
-- CONNECT BY memid = PRIOR recommendedby
-- ORDER BY member ASC, recommender DESC;
