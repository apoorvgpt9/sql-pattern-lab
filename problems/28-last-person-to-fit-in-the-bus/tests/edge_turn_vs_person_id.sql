-- Boarding order is turn, NOT person_id. Taking the people in person_id order gives a different answer.
-- By turn:      Cleo 400, Abe 400, Dina 300, Bea 500 -> totals 400, 800, 1100, ...  -> Abe is the last to fit
-- By person_id: Abe 400, Bea 500, Cleo 400, Dina 300 -> totals 400, 900, 1300, ...  -> (wrong) Bea
INSERT INTO Queue (person_id, person_name, weight, turn) VALUES
  (1, 'Abe',  400, 2),
  (2, 'Bea',  500, 4),
  (3, 'Cleo', 400, 1),
  (4, 'Dina', 300, 3);

-- expect: Abe | in turn order the totals are 400 (Cleo), 800 (Abe); Dina would make 1100
