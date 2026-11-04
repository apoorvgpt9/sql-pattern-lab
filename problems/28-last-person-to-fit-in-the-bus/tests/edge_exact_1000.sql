-- The running total reaches exactly 1000: that person still fits. The next person overflows by a hair.
INSERT INTO Queue (person_id, person_name, weight, turn) VALUES
  (1, 'Abe', 400, 1),
  (2, 'Bea', 350, 2),
  (3, 'Cal', 250, 3),
  (4, 'Dot',  20, 4);

-- expect: Cal | 400 + 350 + 250 = 1000 exactly, which fits; Dot would make 1020
