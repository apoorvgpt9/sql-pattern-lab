-- Member 22 was recommended by nobody (recommendedby NULL): it contributes no rows at all, not a row
-- with a NULL recommender. Member 12 has a one-step chain. Member 30 hangs BELOW 22 and must not appear.
INSERT INTO members (memid, surname, firstname, address, zipcode, telephone, recommendedby, joindate) VALUES
  (4,  'Petrov', 'Dina', '4 Ash Court',  10004, '(555) 010-0004', NULL, '2023-01-04 09:00:00'),
  (12, 'Sato',   'Lea',  '12 Maple Mews',10012, '(555) 010-0012', 4,    '2023-01-12 09:00:00'),
  (22, 'Haddad', 'Nia',  '22 Larch End', 10022, '(555) 010-0022', NULL, '2023-01-22 09:00:00'),
  (30, 'Varga',  'Oren', '30 Beech Rd',  10030, '(555) 010-0030', 22,   '2023-01-30 09:00:00');

-- expect: 12,4,Dina,Petrov | 12's only recommender; 4 is a chain top (NULL), so the chain ends here
-- (no rows for 22: it has no recommender; 30 is a descendant of 22, not an ancestor)
