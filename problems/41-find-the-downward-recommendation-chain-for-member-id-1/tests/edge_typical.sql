-- Typical: member 1 has two direct recommendees (2, 5); 2's line goes two levels further (4, then 7).
-- A second, unrelated tree hangs off member 3 (6, 8). GUEST (0) and the tops of both trees have
-- recommendedby NULL, which is where any upward walk stops.
--
--   1 -> 2 -> 4 -> 7        3 -> 6 -> 8        0 (GUEST)
--   1 -> 5
INSERT INTO members (memid, surname, firstname, address, zipcode, telephone, recommendedby, joindate) VALUES
  (0, 'GUEST',   'GUEST', 'n/a',          0,     '(000) 000-0000', NULL, '2023-01-01 00:00:00'),
  (1, 'Lin',     'Avery', '1 Elm Row',    10001, '(555) 010-0001', NULL, '2023-01-02 09:00:00'),
  (2, 'Okafor',  'Bea',   '2 Oak Lane',   10002, '(555) 010-0002', 1,    '2023-01-05 10:00:00'),
  (3, 'Duarte',  'Cal',   '3 Pine Way',   10003, '(555) 010-0003', NULL, '2023-01-07 11:00:00'),
  (4, 'Petrov',  'Dina',  '4 Ash Court',  10004, '(555) 010-0004', 2,    '2023-02-01 12:00:00'),
  (5, 'Novak',   'Eli',   '5 Birch Road', 10005, '(555) 010-0005', 1,    '2023-02-03 13:00:00'),
  (6, 'Moreau',  'Fay',   '6 Cedar St',   10006, '(555) 010-0006', 3,    '2023-02-09 14:00:00'),
  (7, 'Tanaka',  'Gus',   '7 Fir Close',  10007, '(555) 010-0007', 4,    '2023-03-01 15:00:00'),
  (8, 'Ruiz',    'Hana',  '8 Yew Grove',  10008, '(555) 010-0008', 6,    '2023-03-04 16:00:00');

-- expect: 2,Bea,Okafor | recommended directly by 1
-- expect: 4,Dina,Petrov | recommended by 2, who was recommended by 1 (two hops)
-- expect: 5,Eli,Novak | recommended directly by 1
-- expect: 7,Gus,Tanaka | recommended by 4 <- 2 <- 1 (three hops)
-- (1 itself is excluded; 0, 3, 6, 8 are not below 1)
