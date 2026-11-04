-- breaks: edge_typical, edge_deep_chain, edge_direction, edge_order
-- MISTAKE: the recursive join is written the wrong way round (m.memid = d.recommendedby), so each
-- step moves to the recommender instead of the recommendees. Starting from member 1 this returns
-- 1's upward chain: empty when 1 is a top member, and 5, 3 in edge_direction.
WITH RECURSIVE chain (memid, firstname, surname, recommendedby) AS (
  SELECT m.memid, m.firstname, m.surname, m.recommendedby
  FROM members m
  JOIN members one ON one.recommendedby = m.memid
  WHERE one.memid = 1
  UNION ALL
  SELECT m.memid, m.firstname, m.surname, m.recommendedby
  FROM members m
  JOIN chain d ON m.memid = d.recommendedby
)
SELECT memid, firstname, surname FROM chain ORDER BY memid;
