-- A run longer than three, and a number that qualifies twice. The result is a SET of numbers:
-- each qualifying number appears once, however many triples or separate runs it has.
-- '3': a run of 5 (ids 1-5) and a separate run of 3 (ids 7-9). '6': a run of 4 (ids 10-13).
INSERT INTO Logs (id, num) VALUES
  (1, '3'), (2, '3'), (3, '3'), (4, '3'), (5, '3'),
  (6, '8'),
  (7, '3'), (8, '3'), (9, '3'),
  (10, '6'), (11, '6'), (12, '6'), (13, '6');

-- expect: 3 | in a run of 5 (ids 1-5) and again in a run of 3 (ids 7-9): reported once
-- expect: 6 | in a run of 4 (ids 10-13): reported once, not twice
