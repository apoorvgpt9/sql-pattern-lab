-- Only the first person boards: the second would overflow. (A third, light person comes after.)
INSERT INTO Queue (person_id, person_name, weight, turn) VALUES
  (1, 'Hal', 900, 1),
  (2, 'Ira', 200, 2),
  (3, 'Jo',   50, 3);

-- expect: Hal | 900 fits; Ira makes 1100; Jo (turn 3) cannot board after the overflow
