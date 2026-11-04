-- Approach 3 (optimal): one ordered pass. For every player's rows ordered by date, ROW_NUMBER marks the
-- first row and LEAD looks at the next date. The first row's next date is the player's second active day;
-- the player returned the day after iff that date is exactly one day later. WHERE rn = 1 leaves one row per
-- player, so AVG is over all players. No join, no second read.
WITH x AS (
  SELECT
    event_date,
    ROW_NUMBER() OVER w AS rn,
    LEAD(event_date) OVER w AS next_date
  FROM Activity
  WINDOW w AS (PARTITION BY player_id ORDER BY event_date)
)
SELECT ROUND(AVG(CASE WHEN DATEDIFF(next_date, event_date) = 1 THEN 1 ELSE 0 END), 2) AS fraction
FROM x
WHERE rn = 1;
