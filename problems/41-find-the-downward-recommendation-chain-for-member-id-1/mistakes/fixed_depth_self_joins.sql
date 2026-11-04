-- breaks: edge_deep_chain
-- MISTAKE: "and so on" means unbounded depth. Three self-joins find levels 1-3 only.
-- It passes edge_typical and edge_order (both at most three levels deep), which is exactly why it
-- survives casual testing; only a chain deeper than the hard-coded joins exposes it.
SELECT memid, firstname, surname FROM (
  SELECT l1.memid, l1.firstname, l1.surname
  FROM members l1 WHERE l1.recommendedby = 1
  UNION ALL
  SELECT l2.memid, l2.firstname, l2.surname
  FROM members l1 JOIN members l2 ON l2.recommendedby = l1.memid
  WHERE l1.recommendedby = 1
  UNION ALL
  SELECT l3.memid, l3.firstname, l3.surname
  FROM members l1 JOIN members l2 ON l2.recommendedby = l1.memid
                  JOIN members l3 ON l3.recommendedby = l2.memid
  WHERE l1.recommendedby = 1
) t
ORDER BY memid;
