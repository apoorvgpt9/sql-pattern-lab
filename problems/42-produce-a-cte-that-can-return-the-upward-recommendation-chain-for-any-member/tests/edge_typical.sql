-- Typical: 12 and 22 share part of their upward chain (5, 1). The chains end at member 1, whose
-- recommendedby is NULL. Member 3's tree and GUEST are unrelated.
--
--   1 -> 5 -> 9 -> 12            3 -> 7          0 (GUEST)
--        5 -> 20 -> 22
INSERT INTO members (memid, surname, firstname, address, zipcode, telephone, recommendedby, joindate) VALUES
  (0,  'GUEST',   'GUEST', 'n/a',         0,     '(000) 000-0000', NULL, '2023-01-01 00:00:00'),
  (1,  'Lin',     'Avery', '1 Elm Row',   10001, '(555) 010-0001', NULL, '2023-01-02 09:00:00'),
  (3,  'Duarte',  'Cal',   '3 Pine Way',  10003, '(555) 010-0003', NULL, '2023-01-03 09:00:00'),
  (5,  'Novak',   'Eli',   '5 Birch Road',10005, '(555) 010-0005', 1,    '2023-01-05 09:00:00'),
  (7,  'Tanaka',  'Gus',   '7 Fir Close', 10007, '(555) 010-0007', 3,    '2023-01-07 09:00:00'),
  (9,  'Brandt',  'Ivo',   '9 Lime Walk', 10009, '(555) 010-0009', 5,    '2023-01-09 09:00:00'),
  (12, 'Sato',    'Lea',   '12 Maple Mews',10012,'(555) 010-0012', 9,    '2023-01-12 09:00:00'),
  (20, 'Ilic',    'Mo',    '20 Alder Row',10020, '(555) 010-0020', 5,    '2023-01-20 09:00:00'),
  (22, 'Haddad',  'Nia',   '22 Larch End',10022, '(555) 010-0022', 20,   '2023-01-22 09:00:00');

-- expect: 12,9,Ivo,Brandt | 12's direct recommender; names are the recommender's (9), not 12's
-- expect: 12,5,Eli,Novak | 9 was recommended by 5
-- expect: 12,1,Avery,Lin | 5 was recommended by 1; 1's recommendedby is NULL, so the chain stops (no NULL row)
-- expect: 22,20,Mo,Ilic | 22's direct recommender
-- expect: 22,5,Eli,Novak | 20 was recommended by 5 (shared with 12's chain)
-- expect: 22,1,Avery,Lin | 5 was recommended by 1; stop
