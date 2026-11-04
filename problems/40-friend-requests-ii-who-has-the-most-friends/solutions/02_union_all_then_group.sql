-- Approach 2: unpivot each friendship into two "person has a friend" rows (one per endpoint),
-- then count per person. UNION ALL, because two different friendships of the same person must
-- stay two rows.
WITH endpoints AS (
  SELECT requester_id AS id FROM RequestAccepted
  UNION ALL
  SELECT accepter_id        FROM RequestAccepted
)
SELECT id, COUNT(*) AS num
FROM endpoints
GROUP BY id
ORDER BY num DESC
LIMIT 1;
