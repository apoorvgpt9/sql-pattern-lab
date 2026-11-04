-- Ordering test: ancestor ids are NOT decreasing up the chain, so "recommender DESC" differs from
-- chain order (nearest first). Rows inserted shuffled; 22 is inserted before 12.
--   7 -> 15 -> 3 -> 12        7 -> 15 -> 22
INSERT INTO members (memid, surname, firstname, address, zipcode, telephone, recommendedby, joindate) VALUES
  (22, 'Haddad', 'Nia',  '22 Larch End',  10022, '(555) 010-0022', 15,   '2023-03-01 09:00:00'),
  (3,  'Duarte', 'Cal',  '3 Pine Way',    10003, '(555) 010-0003', 15,   '2023-02-01 09:00:00'),
  (7,  'Tanaka', 'Gus',  '7 Fir Close',   10007, '(555) 010-0007', NULL, '2023-01-01 09:00:00'),
  (12, 'Sato',   'Lea',  '12 Maple Mews', 10012, '(555) 010-0012', 3,    '2023-02-15 09:00:00'),
  (15, 'Ruiz',   'Hana', '15 Poplar St',  10015, '(555) 010-0015', 7,    '2023-01-15 09:00:00');

-- expect: 12,15,Hana,Ruiz | member 12 first; its recommenders by id DESC: 15 (two hops up) first
-- expect: 12,7,Gus,Tanaka | 7 (three hops up, the top)
-- expect: 12,3,Cal,Duarte | 3 (the direct recommender) last, although it is nearest
-- expect: 22,15,Hana,Ruiz | member 22: direct recommender 15
-- expect: 22,7,Gus,Tanaka | then 7, the top
