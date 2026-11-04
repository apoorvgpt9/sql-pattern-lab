-- ASSUMPTION (README "Assumptions"): "consecutive" means adjacent in id ORDER, not "id differs by 1".
-- Ids 3, 6, 7, 8 are missing (rows were deleted). 'A' sits at ids 1, 2, 4: three adjacent rows with a hole in the ids.
-- 'B' sits at ids 5, 9, 10: again adjacent rows. 'C' has only two rows.
INSERT INTO Logs (id, num) VALUES
  (1, 'A'), (2, 'A'), (4, 'A'),
  (5, 'B'), (9, 'B'), (10, 'B'),
  (11, 'C'), (13, 'C');

-- expect: A | rows with ids 1, 2, 4 are three adjacent rows in id order (id 3 does not exist)
-- expect: B | rows with ids 5, 9, 10 are three adjacent rows in id order
