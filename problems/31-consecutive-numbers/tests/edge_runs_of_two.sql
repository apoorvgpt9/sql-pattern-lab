-- Many repeats, none three in a row: pairs and alternations only.
INSERT INTO Logs (id, num) VALUES
  (1, 'A'), (2, 'A'),
  (3, 'B'), (4, 'B'),
  (5, 'A'), (6, 'A'),
  (7, 'B'),
  (8, 'A'),
  (9, 'B');

-- expect-empty: the longest run is 2 ('A' ids 1-2, 'B' ids 3-4, 'A' ids 5-6); no number appears three times in a row
