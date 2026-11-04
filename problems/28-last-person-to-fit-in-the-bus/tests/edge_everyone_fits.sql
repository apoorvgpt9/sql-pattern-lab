-- Nobody overflows: total weight is 600. The answer is simply the last person in turn order.
INSERT INTO Queue (person_id, person_name, weight, turn) VALUES
  (1, 'Kai', 100, 1),
  (2, 'Lia', 200, 2),
  (3, 'Moe', 300, 3);

-- expect: Moe | totals 100, 300, 600 all fit; the last person in turn order is Moe
