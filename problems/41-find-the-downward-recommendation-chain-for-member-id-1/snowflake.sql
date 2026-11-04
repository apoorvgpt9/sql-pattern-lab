-- UNVERIFIED: Snowflake version of the optimal approach (03). CI cannot run Snowflake.
-- Snowflake accepts WITH RECURSIVE (RECURSIVE is optional there) and also CONNECT BY; both are below.
-- Differences are noted in README section 9.
WITH RECURSIVE downline (memid, firstname, surname) AS (
  SELECT memid, firstname, surname
  FROM members
  WHERE recommendedby = 1
  UNION ALL
  SELECT m.memid, m.firstname, m.surname
  FROM members m
  JOIN downline d ON m.recommendedby = d.memid
)
SELECT memid, firstname, surname
FROM downline
ORDER BY memid;

-- Equivalent CONNECT BY form (Oracle-style hierarchical query):
-- SELECT memid, firstname, surname
-- FROM members
-- START WITH recommendedby = 1
-- CONNECT BY recommendedby = PRIOR memid
-- ORDER BY memid;
