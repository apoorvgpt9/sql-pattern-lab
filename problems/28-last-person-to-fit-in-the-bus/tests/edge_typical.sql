-- Five people. person_id does not follow the boarding order (turn).
-- By turn: Ana 250, Ben 300, Cho 200, Dev 150, Eli 120 -> running totals 250, 550, 750, 900, 1020.
INSERT INTO Queue (person_id, person_name, weight, turn) VALUES
  (3, 'Ana', 250, 1),
  (5, 'Ben', 300, 2),
  (1, 'Cho', 200, 3),
  (4, 'Dev', 150, 4),
  (2, 'Eli', 120, 5);

-- expect: Dev | running total after Dev is 900 (<= 1000); after Eli it would be 1020, which does not fit
