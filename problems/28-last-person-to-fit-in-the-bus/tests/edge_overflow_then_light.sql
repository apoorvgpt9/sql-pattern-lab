-- Boarding stops at the first overflow. Persons after it may be light enough to squeeze in
-- if you skipped the heavy one, but they cannot board: "in turn order, stop at the first overflow".
-- Running totals by turn: 600, 900, 1100 (overflow), 1150, 1200.
INSERT INTO Queue (person_id, person_name, weight, turn) VALUES
  (1, 'Eve', 600, 1),
  (2, 'Fay', 300, 2),
  (3, 'Gus', 200, 3),
  (4, 'Hal',  50, 4),
  (5, 'Ivy',  50, 5);

-- expect: Fay | total 900 fits; Gus (turn 3) would make 1100, so boarding stops there. Hal and Ivy never board
