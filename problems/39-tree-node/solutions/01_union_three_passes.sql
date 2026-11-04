-- Approach 1 (brute force): one SELECT per label, glued with UNION ALL.
-- Natural first attempt: the wording lists three labels, so write three queries.
-- The Leaf branch filters NULLs out of its NOT IN list; without that filter it returns nothing.
SELECT id, 'Root' AS type
FROM Tree
WHERE p_id IS NULL

UNION ALL

SELECT id, 'Inner'
FROM Tree
WHERE p_id IS NOT NULL
  AND id IN (SELECT p_id FROM Tree)

UNION ALL

SELECT id, 'Leaf'
FROM Tree
WHERE p_id IS NOT NULL
  AND id NOT IN (SELECT p_id FROM Tree WHERE p_id IS NOT NULL);
