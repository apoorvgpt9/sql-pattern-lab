-- Approach 3 (optimal): simulate the boarding. Start with the first person; keep adding the next turn while
-- the total still fits; stop at the first overflow (the recursive step produces no row, so the recursion ends).
-- Work is proportional to the number of people who board (at most 1000 for positive integer weights),
-- not to the length of the queue. Relies on turns being 1..n with no gaps (spec), so "next" is turn + 1.
WITH RECURSIVE boarding AS (
  SELECT turn, person_name, weight AS total_weight
  FROM Queue
  WHERE turn = (SELECT MIN(turn) FROM Queue)
    AND weight <= 1000
  UNION ALL
  SELECT q.turn, q.person_name, b.total_weight + q.weight
  FROM boarding b
  JOIN Queue q ON q.turn = b.turn + 1
  WHERE b.total_weight + q.weight <= 1000
)
SELECT person_name
FROM boarding
ORDER BY turn DESC
LIMIT 1;
