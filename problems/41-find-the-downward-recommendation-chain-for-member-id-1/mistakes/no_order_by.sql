-- breaks: edge_order, edge_typical
-- MISTAKE: a recursive CTE returns rows in the order it discovers them (level by level), which
-- looks sorted on small, tidy data. The spec orders by memid, and level order is not memid order.
WITH RECURSIVE downline (memid, firstname, surname) AS (
  SELECT memid, firstname, surname FROM members WHERE recommendedby = 1
  UNION ALL
  SELECT m.memid, m.firstname, m.surname
  FROM members m JOIN downline d ON m.recommendedby = d.memid
)
SELECT memid, firstname, surname FROM downline;
