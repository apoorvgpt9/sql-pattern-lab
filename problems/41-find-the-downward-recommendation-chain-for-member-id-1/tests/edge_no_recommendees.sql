-- Member 1 exists but has recommended nobody. Others recommend each other (3 -> 4 -> 5).
INSERT INTO members (memid, surname, firstname, address, zipcode, telephone, recommendedby, joindate) VALUES
  (0, 'GUEST',  'GUEST', 'n/a',        0,     '(000) 000-0000', NULL, '2023-01-01 00:00:00'),
  (1, 'Lin',    'Avery', '1 Elm Row',  10001, '(555) 010-0001', NULL, '2023-01-02 09:00:00'),
  (3, 'Duarte', 'Cal',   '3 Pine Way', 10003, '(555) 010-0003', NULL, '2023-01-07 11:00:00'),
  (4, 'Petrov', 'Dina',  '4 Ash Court',10004, '(555) 010-0004', 3,    '2023-02-01 12:00:00'),
  (5, 'Novak',  'Eli',   '5 Birch Road',10005,'(555) 010-0005', 4,    '2023-02-03 13:00:00');

-- expect-empty: no row has recommendedby = 1, so member 1 has no direct or indirect recommendees
