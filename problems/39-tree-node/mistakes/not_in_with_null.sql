-- breaks: edge_typical, edge_chain, edge_star
-- MISTAKE: the root's p_id is NULL, so the list (SELECT p_id FROM Tree) always contains a NULL.
-- id NOT IN (list with NULL) is never TRUE (it is FALSE or UNKNOWN), so the Leaf branch never fires
-- and every leaf falls through to ELSE 'Inner'. Any valid tree with a leaf triggers it.
SELECT
  id,
  CASE
    WHEN p_id IS NULL THEN 'Root'
    WHEN id NOT IN (SELECT p_id FROM Tree) THEN 'Leaf'
    ELSE 'Inner'
  END AS type
FROM Tree;
