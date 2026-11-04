-- breaks: edge_order
-- MISTAKE: ordering by distance up the chain (nearest recommender first) instead of recommender id
-- DESC. On data where ids grow down the tree (recommenders joined earlier, so have smaller ids) the
-- two orders coincide - edge_typical and edge_deep_chain pass - so only an ordering test catches it.
WITH RECURSIVE recommenders (member, recommender, hops) AS (
  SELECT memid, recommendedby, 1 FROM members WHERE recommendedby IS NOT NULL
  UNION ALL
  SELECT r.member, m.recommendedby, r.hops + 1
  FROM recommenders r JOIN members m ON m.memid = r.recommender
  WHERE m.recommendedby IS NOT NULL
)
SELECT r.member, r.recommender, m.firstname, m.surname
FROM recommenders r
JOIN members m ON m.memid = r.recommender
WHERE r.member IN (12, 22)
ORDER BY r.member ASC, r.hops ASC;
