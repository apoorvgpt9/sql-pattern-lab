-- UNVERIFIED: Snowflake version of the optimal approach (03). CI cannot run Snowflake.
-- Differences are noted in README section 9. MAX_BY avoids the global ORDER BY ... LIMIT 1;
-- it returns one arbitrary id among ties, which is fine because the spec guarantees a single winner.
WITH per_role AS (
  SELECT requester_id AS id, COUNT(*) AS n FROM RequestAccepted GROUP BY requester_id
  UNION ALL
  SELECT accepter_id,        COUNT(*)      FROM RequestAccepted GROUP BY accepter_id
),
per_person AS (
  SELECT id, SUM(n) AS num
  FROM per_role
  GROUP BY id
)
SELECT MAX_BY(id, num) AS id,
       MAX(num)        AS num
FROM per_person
HAVING COUNT(*) > 0;   -- an aggregate without GROUP BY returns one row even on empty input; keep the result empty
