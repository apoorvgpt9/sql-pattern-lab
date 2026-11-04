-- breaks: edge_typical, edge_no_recommendees, edge_deep_chain, edge_direction, edge_order
-- MISTAKE: anchoring on member 1 itself (a natural "start from the root" habit) and forgetting to
-- drop it at the end. Member 1 is not their own recommendee.
WITH RECURSIVE downline (memid, firstname, surname) AS (
  SELECT memid, firstname, surname FROM members WHERE memid = 1
  UNION ALL
  SELECT m.memid, m.firstname, m.surname
  FROM members m JOIN downline d ON m.recommendedby = d.memid
)
SELECT memid, firstname, surname FROM downline ORDER BY memid;
