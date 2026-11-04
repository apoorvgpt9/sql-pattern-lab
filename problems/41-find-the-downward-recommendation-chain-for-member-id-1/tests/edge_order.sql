-- Ordering test: discovery order (level by level) differs from memid order, and rows are inserted
-- shuffled. Level 1: 9, 12. Level 2: 3 (under 9), 2 (under 12). Level 3: 11 (under 3).
-- A recursive CTE emits 9, 12, 3, 2, 11; the required order is 2, 3, 9, 11, 12.
INSERT INTO members (memid, surname, firstname, address, zipcode, telephone, recommendedby, joindate) VALUES
  (11, 'Lund',   'Kai',   '11 Rowan Lane', 10011, '(555) 010-0011', 3,    '2023-05-01 09:00:00'),
  (3,  'Duarte', 'Cal',   '3 Pine Way',    10003, '(555) 010-0003', 9,    '2023-04-01 09:00:00'),
  (12, 'Sato',   'Lea',   '12 Maple Mews', 10012, '(555) 010-0012', 1,    '2023-02-01 09:00:00'),
  (1,  'Lin',    'Avery', '1 Elm Row',     10001, '(555) 010-0001', NULL, '2023-01-01 09:00:00'),
  (2,  'Okafor', 'Bea',   '2 Oak Lane',    10002, '(555) 010-0002', 12,   '2023-04-02 09:00:00'),
  (9,  'Brandt', 'Ivo',   '9 Lime Walk',   10009, '(555) 010-0009', 1,    '2023-02-02 09:00:00');

-- expect: 2,Bea,Okafor | 2 <- 12 <- 1; first by memid although found on level 2
-- expect: 3,Cal,Duarte | 3 <- 9 <- 1
-- expect: 9,Ivo,Brandt | recommended directly by 1
-- expect: 11,Kai,Lund | 11 <- 3 <- 9 <- 1 (level 3), sorts before 12
-- expect: 12,Lea,Sato | recommended directly by 1; last by memid although found on level 1
