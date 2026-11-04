-- A single chain ten members long: 1 -> 2 -> 3 -> ... -> 10. Depth is unbounded in the spec, so a
-- query with a fixed number of self-joins stops too early.
INSERT INTO members (memid, surname, firstname, address, zipcode, telephone, recommendedby, joindate) VALUES
  (1,  'Lin',     'Avery', '1 Elm Row',    10001, '(555) 010-0001', NULL, '2023-01-01 09:00:00'),
  (2,  'Okafor',  'Bea',   '2 Oak Lane',   10002, '(555) 010-0002', 1,    '2023-01-02 09:00:00'),
  (3,  'Duarte',  'Cal',   '3 Pine Way',   10003, '(555) 010-0003', 2,    '2023-01-03 09:00:00'),
  (4,  'Petrov',  'Dina',  '4 Ash Court',  10004, '(555) 010-0004', 3,    '2023-01-04 09:00:00'),
  (5,  'Novak',   'Eli',   '5 Birch Road', 10005, '(555) 010-0005', 4,    '2023-01-05 09:00:00'),
  (6,  'Moreau',  'Fay',   '6 Cedar St',   10006, '(555) 010-0006', 5,    '2023-01-06 09:00:00'),
  (7,  'Tanaka',  'Gus',   '7 Fir Close',  10007, '(555) 010-0007', 6,    '2023-01-07 09:00:00'),
  (8,  'Ruiz',    'Hana',  '8 Yew Grove',  10008, '(555) 010-0008', 7,    '2023-01-08 09:00:00'),
  (9,  'Brandt',  'Ivo',   '9 Lime Walk',  10009, '(555) 010-0009', 8,    '2023-01-09 09:00:00'),
  (10, 'Mensah',  'Jo',    '10 Holly Row', 10010, '(555) 010-0010', 9,    '2023-01-10 09:00:00');

-- expect: 2,Bea,Okafor | depth 1
-- expect: 3,Cal,Duarte | depth 2
-- expect: 4,Dina,Petrov | depth 3
-- expect: 5,Eli,Novak | depth 4: beyond a three-level self-join
-- expect: 6,Fay,Moreau | depth 5
-- expect: 7,Gus,Tanaka | depth 6
-- expect: 8,Hana,Ruiz | depth 7
-- expect: 9,Ivo,Brandt | depth 8
-- expect: 10,Jo,Mensah | depth 9
