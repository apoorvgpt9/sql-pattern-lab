-- Member 1 is in the MIDDLE of a chain: 3 -> 5 -> 1 -> 4. Only what is below 1 counts.
-- 2 is 1's "sibling" (also recommended by 5): same chain, different branch, not below 1.
INSERT INTO members (memid, surname, firstname, address, zipcode, telephone, recommendedby, joindate) VALUES
  (1, 'Lin',    'Avery', '1 Elm Row',    10001, '(555) 010-0001', 5,    '2023-03-01 09:00:00'),
  (2, 'Okafor', 'Bea',   '2 Oak Lane',   10002, '(555) 010-0002', 5,    '2023-03-02 09:00:00'),
  (3, 'Duarte', 'Cal',   '3 Pine Way',   10003, '(555) 010-0003', NULL, '2023-01-01 09:00:00'),
  (4, 'Petrov', 'Dina',  '4 Ash Court',  10004, '(555) 010-0004', 1,    '2023-03-05 09:00:00'),
  (5, 'Novak',  'Eli',   '5 Birch Road', 10005, '(555) 010-0005', 3,    '2023-02-01 09:00:00');

-- expect: 4,Dina,Petrov | the only member below 1. Not 5 or 3 (they are above 1: the upward chain), not 2 (a sibling)
