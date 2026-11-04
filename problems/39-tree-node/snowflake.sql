-- UNVERIFIED: Snowflake version of the optimal approach (03). CI cannot run Snowflake.
-- Same shape as MySQL; differences are noted in README section 9.
WITH parents AS (
  SELECT DISTINCT p_id
  FROM Tree
  WHERE p_id IS NOT NULL
)
SELECT
  t.id,
  CASE
    WHEN t.p_id IS NULL       THEN 'Root'
    WHEN par.p_id IS NOT NULL THEN 'Inner'
    ELSE 'Leaf'
  END AS type
FROM Tree t
LEFT JOIN parents par
  ON par.p_id = t.id;
