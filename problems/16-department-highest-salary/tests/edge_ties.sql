-- Ties: two employees share the maximum in one department; a tie one step below the maximum in
-- another department must NOT be returned; a department where everyone is paid the same.
INSERT INTO Department (id, name) VALUES (1, 'IT'), (2, 'Sales'), (3, 'Ops');

INSERT INTO Employee (id, name, salary, departmentId) VALUES
  (1, 'Jim',   90000, 1),
  (2, 'Zoe',   90000, 1),  -- ties with Jim at the IT maximum
  (3, 'Joe',   70000, 1),
  (4, 'Henry', 80000, 2),
  (5, 'Sam',   70000, 2),
  (6, 'Max',   70000, 2),  -- Sam and Max tie, but one step below Henry: not the maximum
  (7, 'Kim',   50000, 3),
  (8, 'Lee',   50000, 3),
  (9, 'Moe',   50000, 3);  -- everyone in Ops is at the maximum

-- expect: IT,Jim,90000 | tied for the IT maximum
-- expect: IT,Zoe,90000 | tied for the IT maximum: ties are all returned, not one arbitrary winner
-- expect: Sales,Henry,80000 | the only Sales employee at 80000; Sam and Max tie lower and are excluded
-- expect: Ops,Kim,50000 | all three Ops employees equal the maximum
-- expect: Ops,Lee,50000 | same
-- expect: Ops,Moe,50000 | same
