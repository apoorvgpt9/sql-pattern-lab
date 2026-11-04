-- Approach 3 (optimal): build the set of ids that are someone's parent once, then LEFT JOIN it.
-- DISTINCT keeps the join 1:1, so a node with many children still yields one row.
WITH parents AS (
  SELECT DISTINCT p_id
  FROM Tree
  WHERE p_id IS NOT NULL
)
SELECT
  t.id,
  CASE
    WHEN t.p_id IS NULL     THEN 'Root'
    WHEN par.p_id IS NOT NULL THEN 'Inner'
    ELSE 'Leaf'
  END AS type
FROM Tree t
LEFT JOIN parents par
  ON par.p_id = t.id;
