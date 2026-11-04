-- breaks: edge_typical, edge_star
-- MISTAKE: LEFT JOIN to the children themselves (not to the distinct parent set). A node with k
-- children produces k joined rows, so it appears k times. edge_chain passes (every node has at most
-- one child), which is why a chain-only test would not catch this.
SELECT
  t.id,
  CASE
    WHEN t.p_id IS NULL THEN 'Root'
    WHEN c.id IS NOT NULL THEN 'Inner'
    ELSE 'Leaf'
  END AS type
FROM Tree t
LEFT JOIN Tree c ON c.p_id = t.id;
