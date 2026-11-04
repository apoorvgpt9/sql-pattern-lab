-- The "three" boundary and departments that have less than three distinct salaries.
-- Duo: 2 distinct salaries over 3 people. Solo: 1 person. Flat: 4 people, one salary.
-- Exact3: exactly 3 distinct salaries (all in). Four: 4 distinct salaries (the lowest is out).
INSERT INTO Department (id, name) VALUES (1, 'Duo'), (2, 'Solo'), (3, 'Flat'), (4, 'Exact3'), (5, 'Four');

INSERT INTO Employee (id, name, salary, departmentId) VALUES
  (1,  'x1', 10, 1), (2,  'x2', 10, 1), (3,  'x3', 20, 1),
  (4,  'y1', 5,  2),
  (5,  'z1', 7,  3), (6,  'z2', 7,  3), (7,  'z3', 7,  3), (8, 'z4', 7, 3),
  (9,  'w1', 30, 4), (10, 'w2', 20, 4), (11, 'w3', 10, 4),
  (12, 'v1', 40, 5), (13, 'v2', 30, 5), (14, 'v3', 20, 5), (15, 'v4', 10, 5);

-- expect: Duo,x1,10 | only two distinct salaries: all three employees are in
-- expect: Duo,x2,10 | same
-- expect: Duo,x3,20 | same
-- expect: Solo,y1,5 | one person
-- expect: Flat,z1,7 | one distinct salary: all four are in
-- expect: Flat,z2,7 | same
-- expect: Flat,z3,7 | same
-- expect: Flat,z4,7 | same
-- expect: Exact3,w1,30 | exactly three distinct salaries: all in
-- expect: Exact3,w2,20 | same
-- expect: Exact3,w3,10 | same: the 3rd distinct salary is the last allowed
-- expect: Four,v1,40 | 1st of 4 distinct salaries
-- expect: Four,v2,30 | 2nd
-- expect: Four,v3,20 | 3rd
-- (v4 at 10 is the 4th distinct salary and is cut.)
