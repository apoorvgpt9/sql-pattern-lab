-- Tests the output order: improvement_score DESC, then name ASC. Employees are inserted in an order that
-- is neither by score nor by name, and two score ties are present. All names are distinct (a tie on both
-- score and name would have no defined order).
INSERT INTO employees (employee_id, name) VALUES
  (1, 'Zoe'), (2, 'Adam'), (3, 'Mia'), (4, 'Ben'), (5, 'Cara');

INSERT INTO performance_reviews (review_id, employee_id, review_date, rating) VALUES
  (1,  1, '2024-01-01', 1), (2,  1, '2024-02-01', 2), (3,  1, '2024-03-01', 3),   -- Zoe: 3 - 1 = 2
  (4,  2, '2024-01-01', 2), (5,  2, '2024-02-01', 3), (6,  2, '2024-03-01', 4),   -- Adam: 4 - 2 = 2
  (7,  3, '2024-01-01', 1), (8,  3, '2024-02-01', 3), (9,  3, '2024-03-01', 5),   -- Mia: 5 - 1 = 4
  (10, 4, '2024-01-01', 1), (11, 4, '2024-02-01', 2), (12, 4, '2024-03-01', 4),   -- Ben: 4 - 1 = 3
  (13, 5, '2024-01-01', 2), (14, 5, '2024-02-01', 3), (15, 5, '2024-03-01', 5);   -- Cara: 5 - 2 = 3

-- expect: 3,Mia,4 | highest score (5 - 1)
-- expect: 4,Ben,3 | score 3 (4 - 1); ties with Cara, 'Ben' sorts before 'Cara'
-- expect: 5,Cara,3 | score 3 (5 - 2)
-- expect: 2,Adam,2 | score 2 (4 - 2); ties with Zoe, 'Adam' sorts before 'Zoe'
-- expect: 1,Zoe,2 | score 2 (3 - 1)
