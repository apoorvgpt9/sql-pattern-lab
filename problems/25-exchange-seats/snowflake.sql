-- UNVERIFIED: Snowflake version of the optimal approach (03). CI cannot run Snowflake.
-- Same shape as MySQL. Differences are noted in README section 9.
WITH moved AS (
  SELECT
    CASE WHEN id % 2 = 0                        THEN id - 1
         WHEN id < (SELECT MAX(id) FROM Seat)   THEN id + 1
         ELSE id
    END AS id,
    student
  FROM Seat
)
SELECT id, student
FROM moved
ORDER BY id;
