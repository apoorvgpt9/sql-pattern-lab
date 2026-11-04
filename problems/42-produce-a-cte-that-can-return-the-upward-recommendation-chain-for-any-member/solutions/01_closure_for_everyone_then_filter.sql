-- Approach 1 (brute force, and the literal reading of the spec): one reusable CTE that holds the
-- upward chain of EVERY member, i.e. the full closure table. The question for 12 and 22 is a filter
-- applied afterwards. Correct, and reusable for any member; it pays for the whole closure each time.
WITH RECURSIVE recommenders (member, recommender) AS (
  SELECT memid, recommendedby                -- anchor: every member and their direct recommender
  FROM members
  WHERE recommendedby IS NOT NULL            -- a chain top has no recommender: no row at all
  UNION ALL
  SELECT r.member, m.recommendedby           -- step: one hop up; carry the start member unchanged
  FROM recommenders r
  JOIN members m ON m.memid = r.recommender
  WHERE m.recommendedby IS NOT NULL          -- stop at the top instead of emitting a NULL recommender
)
SELECT r.member, r.recommender, m.firstname, m.surname   -- names belong to the recommender
FROM recommenders r
JOIN members m ON m.memid = r.recommender
WHERE r.member IN (12, 22)
ORDER BY r.member ASC, r.recommender DESC;
