-- Ties inside the top three. IT has two people at the top salary and two at the third salary: the
-- answer has FIVE IT rows, because "top three" counts distinct salary values, not people. Sales has
-- three people at one salary and one at another: only two distinct values, so all four are returned.
INSERT INTO Department (id, name) VALUES (1, 'IT'), (2, 'Sales');

INSERT INTO Employee (id, name, salary, departmentId) VALUES
  (1, 'a1', 90, 1),
  (2, 'a2', 90, 1),  -- ties a1 for the 1st distinct salary
  (3, 'a3', 80, 1),  -- 2nd distinct salary
  (4, 'a4', 70, 1),  -- 3rd distinct salary ...
  (5, 'a5', 70, 1),  -- ... shared with a4: both are in
  (6, 'a6', 60, 1),  -- 4th distinct salary: out
  (7, 'b1', 50, 2),
  (8, 'b2', 50, 2),
  (9, 'b3', 50, 2),
  (10,'b4', 40, 2);

-- expect: IT,a1,90 | 1st distinct salary
-- expect: IT,a2,90 | tied with a1: same rank, both returned
-- expect: IT,a3,80 | 2nd distinct salary; the tie above does not use up a slot
-- expect: IT,a4,70 | 3rd distinct salary
-- expect: IT,a5,70 | tied for the 3rd distinct salary; RANK would give it rank 4 and drop both a4 and a5
-- expect: Sales,b1,50 | Sales has two distinct salaries (50, 40), so everyone qualifies
-- expect: Sales,b2,50 | same
-- expect: Sales,b3,50 | same
-- expect: Sales,b4,40 | same
