-- breaks: edge_deep_chain
-- MISTAKE: three self-joins upward find the recommender, their recommender and one more - nothing
-- beyond. Passes every dataset whose chains are at most three long (all the others here).
SELECT t.member, t.recommender, m.firstname, m.surname
FROM (
  SELECT a.memid AS member, a.recommendedby AS recommender FROM members a
  UNION ALL
  SELECT a.memid, b.recommendedby FROM members a JOIN members b ON b.memid = a.recommendedby
  UNION ALL
  SELECT a.memid, c.recommendedby FROM members a JOIN members b ON b.memid = a.recommendedby
                                                 JOIN members c ON c.memid = b.recommendedby
) t
JOIN members m ON m.memid = t.recommender
WHERE t.member IN (12, 22)
ORDER BY t.member ASC, t.recommender DESC;
