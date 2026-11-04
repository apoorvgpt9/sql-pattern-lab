-- breaks: edge_typical, edge_chain, edge_star
-- MISTAKE: CASE stops at the first true branch. Testing "has a child" first labels a root that has
-- children as Inner. Only a lone root (edge_lone_root) survives, which is why the order matters.
SELECT
  id,
  CASE
    WHEN id IN (SELECT p_id FROM Tree) THEN 'Inner'
    WHEN p_id IS NULL THEN 'Root'
    ELSE 'Leaf'
  END AS type
FROM Tree;
