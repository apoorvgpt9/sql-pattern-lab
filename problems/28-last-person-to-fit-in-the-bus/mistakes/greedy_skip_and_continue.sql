-- breaks: edge_overflow_then_light
-- MISTAKE: Modelling the bus as 'a person boards if they still fit' and carrying on past an overflow. The spec stops at the
-- first person who does not fit; this version lets later, lighter people board around them.
WITH RECURSIVE r AS (
  SELECT turn, person_name, weight AS total_weight
  FROM Queue
  WHERE turn = (SELECT MIN(turn) FROM Queue) AND weight <= 1000
  UNION ALL
  SELECT q.turn,
         CASE WHEN r.total_weight + q.weight <= 1000 THEN q.person_name ELSE r.person_name END,
         CASE WHEN r.total_weight + q.weight <= 1000 THEN r.total_weight + q.weight ELSE r.total_weight END
  FROM r
  JOIN Queue q ON q.turn = r.turn + 1
)
SELECT person_name FROM r ORDER BY turn DESC LIMIT 1;
