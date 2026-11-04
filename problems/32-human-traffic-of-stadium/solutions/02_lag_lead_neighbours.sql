-- Approach 2: look at the two previous and two next busy days with LAG/LEAD (over the filtered
-- rows) and check their ids are adjacent. A row qualifies if it starts, sits inside, or ends a
-- window of three consecutive ids. One sort, but five window columns and a three-way OR.
WITH busy AS (
  SELECT id, visit_date, people,
         LAG(id, 2)  OVER w AS prev2,
         LAG(id, 1)  OVER w AS prev1,
         LEAD(id, 1) OVER w AS next1,
         LEAD(id, 2) OVER w AS next2
  FROM Stadium
  WHERE people >= 100
  WINDOW w AS (ORDER BY id)
)
SELECT id, visit_date, people
FROM busy
WHERE (next1 = id + 1 AND next2 = id + 2)
   OR (prev1 = id - 1 AND next1 = id + 1)
   OR (prev2 = id - 2 AND prev1 = id - 1)
ORDER BY visit_date;
