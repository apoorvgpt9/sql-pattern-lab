-- Only the 3 MOST RECENT reviews matter, not the whole history.
-- Ava: old history falls, but her last three rise -> qualifies.
-- Bo: first three rise, but his last three (3,5,4) do not -> excluded.
-- Cy: four reviews, last three rise -> qualifies, with the oldest of the three (not of all four) as the base.
INSERT INTO employees (employee_id, name) VALUES (1, 'Ava'), (2, 'Bo'), (3, 'Cy');

INSERT INTO performance_reviews (review_id, employee_id, review_date, rating) VALUES
  (1,  1, '2022-01-01', 5), (2,  1, '2022-06-01', 2), (3,  1, '2023-01-01', 1),
  (4,  1, '2023-06-01', 3), (5,  1, '2024-01-01', 4),
  (6,  2, '2022-01-01', 1), (7,  2, '2022-06-01', 2), (8,  2, '2023-01-01', 3),
  (9,  2, '2023-06-01', 5), (10, 2, '2024-01-01', 4),
  (11, 3, '2023-01-01', 3), (12, 3, '2023-06-01', 1), (13, 3, '2023-12-01', 2), (14, 3, '2024-01-01', 3);

-- expect: 1,Ava,3 | last three by date are 1,3,4 (strictly rising); score = 4 - 1 = 3. Her earlier 5,2 are ignored
-- expect: 3,Cy,2 | last three are 1,2,3 (the first review, 3, is ignored); score = 3 - 1 = 2
-- (Bo: last three are 3,5,4, the final step falls, so excluded although his first three rise.)
