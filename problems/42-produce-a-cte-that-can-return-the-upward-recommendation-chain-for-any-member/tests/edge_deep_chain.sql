-- One long chain 1 -> 2 -> ... -> 11 -> 12 -> 22. Member 12 has 11 ancestors; member 22 has 12
-- (member 12 is itself one of 22's ancestors). A fixed number of self-joins stops early.
INSERT INTO members (memid, surname, firstname, address, zipcode, telephone, recommendedby, joindate) VALUES
  (1,  'Lin',     'Avery', '1 Elm Row',     10001, '(555) 010-0001', NULL, '2023-01-01 09:00:00'),
  (2,  'Okafor',  'Bea',   '2 Oak Lane',    10002, '(555) 010-0002', 1,    '2023-01-02 09:00:00'),
  (3,  'Duarte',  'Cal',   '3 Pine Way',    10003, '(555) 010-0003', 2,    '2023-01-03 09:00:00'),
  (4,  'Petrov',  'Dina',  '4 Ash Court',   10004, '(555) 010-0004', 3,    '2023-01-04 09:00:00'),
  (5,  'Novak',   'Eli',   '5 Birch Road',  10005, '(555) 010-0005', 4,    '2023-01-05 09:00:00'),
  (6,  'Moreau',  'Fay',   '6 Cedar St',    10006, '(555) 010-0006', 5,    '2023-01-06 09:00:00'),
  (7,  'Tanaka',  'Gus',   '7 Fir Close',   10007, '(555) 010-0007', 6,    '2023-01-07 09:00:00'),
  (8,  'Ruiz',    'Hana',  '8 Yew Grove',   10008, '(555) 010-0008', 7,    '2023-01-08 09:00:00'),
  (9,  'Brandt',  'Ivo',   '9 Lime Walk',   10009, '(555) 010-0009', 8,    '2023-01-09 09:00:00'),
  (10, 'Mensah',  'Jo',    '10 Holly Row',  10010, '(555) 010-0010', 9,    '2023-01-10 09:00:00'),
  (11, 'Lund',    'Kai',   '11 Rowan Lane', 10011, '(555) 010-0011', 10,   '2023-01-11 09:00:00'),
  (12, 'Sato',    'Lea',   '12 Maple Mews', 10012, '(555) 010-0012', 11,   '2023-01-12 09:00:00'),
  (22, 'Haddad',  'Nia',   '22 Larch End',  10022, '(555) 010-0022', 12,   '2023-01-22 09:00:00');

-- expect: 12,11,Kai,Lund | 1 hop up
-- expect: 12,10,Jo,Mensah | 2 hops
-- expect: 12,9,Ivo,Brandt | 3 hops
-- expect: 12,8,Hana,Ruiz | 4 hops: beyond a three-join query
-- expect: 12,7,Gus,Tanaka | 5 hops
-- expect: 12,6,Fay,Moreau | 6 hops
-- expect: 12,5,Eli,Novak | 7 hops
-- expect: 12,4,Dina,Petrov | 8 hops
-- expect: 12,3,Cal,Duarte | 9 hops
-- expect: 12,2,Bea,Okafor | 10 hops
-- expect: 12,1,Avery,Lin | 11 hops; 1 is the top (NULL), stop
-- expect: 22,12,Lea,Sato | 22's direct recommender is 12; sorted first because 12 is the largest id
-- expect: 22,11,Kai,Lund | 2 hops up from 22 (via 12); then 12's chain follows in id DESC order
-- expect: 22,10,Jo,Mensah | 3 hops up from 22 (via 12)
-- expect: 22,9,Ivo,Brandt | 4 hops up from 22 (via 12)
-- expect: 22,8,Hana,Ruiz | 5 hops up from 22 (via 12)
-- expect: 22,7,Gus,Tanaka | 6 hops up from 22 (via 12)
-- expect: 22,6,Fay,Moreau | 7 hops up from 22 (via 12)
-- expect: 22,5,Eli,Novak | 8 hops up from 22 (via 12)
-- expect: 22,4,Dina,Petrov | 9 hops up from 22 (via 12)
-- expect: 22,3,Cal,Duarte | 10 hops up from 22 (via 12)
-- expect: 22,2,Bea,Okafor | 11 hops up from 22 (via 12)
-- expect: 22,1,Avery,Lin | 12 hops; the top
