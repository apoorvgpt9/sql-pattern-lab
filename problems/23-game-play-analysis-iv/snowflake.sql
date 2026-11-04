-- UNVERIFIED: Snowflake version of the optimal approach (03). CI cannot run Snowflake.
-- QUALIFY keeps each player's first row; LEAD is still computed over all of the player's rows because
-- window functions are evaluated before QUALIFY filters.
WITH x AS (
  SELECT
    event_date,
    LEAD(event_date) OVER (PARTITION BY player_id ORDER BY event_date) AS next_date
  FROM Activity
  QUALIFY ROW_NUMBER() OVER (PARTITION BY player_id ORDER BY event_date) = 1
)
SELECT ROUND(AVG(IFF(DATEDIFF('day', event_date, next_date) = 1, 1, 0)), 2) AS fraction
FROM x;
