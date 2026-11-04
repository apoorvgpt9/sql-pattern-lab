-- breaks: edge_lone_root
-- MISTAKE: "no children -> Leaf" tested before "no parent -> Root". Passes every tree with at least
-- one edge, because there the root always has a child. The one-node tree comes out as Leaf.
WITH parents AS (SELECT DISTINCT p_id FROM Tree WHERE p_id IS NOT NULL)
SELECT
  t.id,
  CASE
    WHEN par.p_id IS NULL THEN 'Leaf'
    WHEN t.p_id IS NULL THEN 'Root'
    ELSE 'Inner'
  END AS type
FROM Tree t
LEFT JOIN parents par ON par.p_id = t.id;
