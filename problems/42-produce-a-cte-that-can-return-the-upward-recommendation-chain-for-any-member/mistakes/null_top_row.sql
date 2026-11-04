-- breaks: edge_typical, edge_no_recommender, edge_both_tops, edge_order, edge_deep_chain
-- MISTAKE: no "recommendedby IS NOT NULL" guard, plus a LEFT JOIN for the names "to be safe".
-- Every chain ends with a (member, NULL) step - the top's missing recommender - and the LEFT JOIN
-- keeps it as a row of NULLs. A member with no recommender at all gets exactly that one NULL row.
WITH RECURSIVE recommenders (member, recommender) AS (
  SELECT memid, recommendedby FROM members
  UNION ALL
  SELECT r.member, m.recommendedby
  FROM recommenders r JOIN members m ON m.memid = r.recommender
)
SELECT r.member, r.recommender, m.firstname, m.surname
FROM recommenders r
LEFT JOIN members m ON m.memid = r.recommender
WHERE r.member IN (12, 22)
ORDER BY r.member ASC, r.recommender DESC;
