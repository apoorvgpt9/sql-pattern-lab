-- breaks: edge_typical, edge_no_recommender, edge_order, edge_deep_chain
-- MISTAKE: joining members on the START member instead of the recommender. Every row of a chain
-- then shows the same name (the member's own), which reads plausibly until you check one row.
WITH RECURSIVE recommenders (member, recommender) AS (
  SELECT memid, recommendedby FROM members WHERE recommendedby IS NOT NULL
  UNION ALL
  SELECT r.member, m.recommendedby
  FROM recommenders r JOIN members m ON m.memid = r.recommender
  WHERE m.recommendedby IS NOT NULL
)
SELECT r.member, r.recommender, m.firstname, m.surname
FROM recommenders r
JOIN members m ON m.memid = r.member
WHERE r.member IN (12, 22)
ORDER BY r.member ASC, r.recommender DESC;
