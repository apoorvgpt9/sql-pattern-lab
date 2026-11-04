-- Neither 12 nor 22 has a recommender, though both recommended other people (40, 41, 42).
INSERT INTO members (memid, surname, firstname, address, zipcode, telephone, recommendedby, joindate) VALUES
  (12, 'Sato',     'Lea',  '12 Maple Mews', 10012, '(555) 010-0012', NULL, '2023-01-12 09:00:00'),
  (22, 'Haddad',   'Nia',  '22 Larch End',  10022, '(555) 010-0022', NULL, '2023-01-22 09:00:00'),
  (40, 'Nakamura', 'Pia',  '40 Hazel Ct',   10040, '(555) 010-0040', 12,   '2023-02-01 09:00:00'),
  (41, 'Lund',     'Kai',  '41 Rowan Lane', 10041, '(555) 010-0041', 22,   '2023-02-02 09:00:00'),
  (42, 'Mensah',   'Jo',   '42 Holly Row',  10042, '(555) 010-0042', 41,   '2023-02-03 09:00:00');

-- expect-empty: 12 and 22 both have recommendedby NULL, so neither has any ancestor; 40-42 are below them, not above
