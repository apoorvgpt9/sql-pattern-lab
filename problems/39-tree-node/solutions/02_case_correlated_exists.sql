-- Approach 2: one pass over Tree, one CASE. "Has a child" is a correlated EXISTS per node.
-- Root is tested first, so a root with children is not called Inner.
SELECT
  t.id,
  CASE
    WHEN t.p_id IS NULL THEN 'Root'
    WHEN EXISTS (SELECT 1 FROM Tree c WHERE c.p_id = t.id) THEN 'Inner'
    ELSE 'Leaf'
  END AS type
FROM Tree t;
