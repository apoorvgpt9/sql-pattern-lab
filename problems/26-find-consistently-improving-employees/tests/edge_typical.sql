-- Typical mix, each employee with exactly 3 reviews: strictly rising, rising, one dip, rising, plus
-- three rising reviews for an employee id that is not in employees (no name, so no output row).
INSERT INTO employees (employee_id, name) VALUES
  (1, 'Alice'), (2, 'Bob'), (3, 'Carol'), (4, 'Dan');

INSERT INTO performance_reviews (review_id, employee_id, review_date, rating) VALUES
  (1,  1, '2023-01-10', 2), (2,  1, '2023-04-10', 3), (3,  1, '2023-07-10', 5),  -- 2 < 3 < 5
  (4,  2, '2023-02-01', 1), (5,  2, '2023-05-01', 4), (6,  2, '2023-08-01', 5),  -- 1 < 4 < 5
  (7,  3, '2023-03-01', 4), (8,  3, '2023-06-01', 3), (9,  3, '2023-09-01', 5),  -- dips in the middle
  (10, 4, '2023-01-15', 2), (11, 4, '2023-04-15', 3), (12, 4, '2023-07-15', 4),  -- 2 < 3 < 4
  (13, 99, '2023-01-01', 1), (14, 99, '2023-02-01', 2), (15, 99, '2023-03-01', 3);

-- expect: 2,Bob,4 | ratings 1,4,5 strictly rise; score = newest 5 - oldest 1 = 4 (largest score, so first)
-- expect: 1,Alice,3 | ratings 2,3,5 rise; score = 5 - 2 = 3
-- expect: 4,Dan,2 | ratings 2,3,4 rise; score = 4 - 2 = 2
-- (Carol: 4,3,5 has a dip, so she is excluded. Employee 99 rises but is not in employees: no name, no row.)
