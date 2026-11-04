-- Approach 3 (optimal): start at member 1's direct recommendees and walk DOWN one level per
-- iteration. Only rows inside 1's subtree are ever produced, and 1 itself is never in the anchor.
WITH RECURSIVE downline (memid, firstname, surname) AS (
  SELECT memid, firstname, surname                 -- anchor: level 1 = recommended by 1
  FROM members
  WHERE recommendedby = 1
  UNION ALL
  SELECT m.memid, m.firstname, m.surname           -- step: members recommended by the previous level
  FROM members m
  JOIN downline d ON m.recommendedby = d.memid
)
SELECT memid, firstname, surname
FROM downline
ORDER BY memid;
