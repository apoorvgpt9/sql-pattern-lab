-- Ten entries. '7' repeats three times at the start; '9' three times at the end; '4' appears three times
-- but never in a row (once, then twice); the pair of '4's (ids 6-7) is a run of only two.
INSERT INTO Logs (id, num) VALUES
  (1, '7'), (2, '7'), (3, '7'),
  (4, '4'),
  (5, '9'),
  (6, '4'), (7, '4'),
  (8, '9'), (9, '9'), (10, '9');

-- expect: 7 | ids 1, 2, 3 all hold '7' (a run at the very start of the table)
-- expect: 9 | ids 8, 9, 10 all hold '9' (a run at the very end); the lone '9' at id 5 is not part of it
-- (num '4' is not reported: it appears 3 times, but as 1 + 2 separated by a '9', never 3 in a row.)
