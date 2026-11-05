-- NULL num. NULL is not a value that can repeat (NULL = NULL is unknown), so three NULLs in a row are
-- not a run - but a NULL row still sits between its neighbours and breaks their adjacency.
-- (Traps: PARTITION BY num puts all NULLs in one partition, so the islands method sees a NULL run of 3;
-- deleting the NULL rows before numbering makes ids 7, 9, 10 look adjacent.)
INSERT INTO Logs (id, num) VALUES
  (1, NULL), (2, NULL), (3, NULL),
  (4, '5'), (5, '5'), (6, '5'),
  (7, '7'), (8, NULL), (9, '7'), (10, '7');

-- expect: 5 | ids 4, 5, 6 all hold '5'
-- ('7' is not reported: ids 7, 9, 10 hold '7' but id 8 sits between them, so the longest run is 2.
--  NULL is not reported: ids 1-3 are NULL, and NULL never equals NULL.)
