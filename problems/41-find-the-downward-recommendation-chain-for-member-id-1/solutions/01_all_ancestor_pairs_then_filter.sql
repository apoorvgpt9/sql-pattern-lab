-- Approach 1 (brute force): build every (member, ancestor) pair by walking UP from every member,
-- then keep the members that have 1 among their ancestors.
-- Natural first attempt when you think "is member 1 somewhere above me?" one member at a time.
-- Correct, but it computes the whole closure table to answer a question about one subtree.
WITH RECURSIVE chain (memid, ancestor) AS (
  SELECT memid, recommendedby                      -- anchor: each member and their direct recommender
  FROM members
  WHERE recommendedby IS NOT NULL
  UNION ALL
  SELECT c.memid, m.recommendedby                  -- step: one more hop up, keeping the start member
  FROM chain c
  JOIN members m ON m.memid = c.ancestor
  WHERE m.recommendedby IS NOT NULL
)
SELECT m.memid, m.firstname, m.surname
FROM chain c
JOIN members m ON m.memid = c.memid
WHERE c.ancestor = 1
ORDER BY m.memid;
