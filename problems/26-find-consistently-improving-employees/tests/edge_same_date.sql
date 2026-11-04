-- ASSUMPTION (README "Assumptions"): the spec does not say what happens when two reviews of one employee have
-- the same date. We break the tie by review_id: the larger review_id counts as the more recent review.
INSERT INTO employees (employee_id, name) VALUES (1, 'Lee'), (2, 'Max');

INSERT INTO performance_reviews (review_id, employee_id, review_date, rating) VALUES
  (1, 1, '2024-01-01', 2),
  (2, 1, '2024-02-01', 3), (3, 1, '2024-02-01', 4),   -- same date: review 3 is the newer one
  (4, 2, '2024-01-01', 2),
  (5, 2, '2024-02-01', 4), (6, 2, '2024-02-01', 3);   -- same date: review 6 is the newer one

-- expect: 1,Lee,2 | ordered by (date, review_id): 2, 3, 4 strictly rise; score = 4 - 2 = 2
-- (Max: ordered by (date, review_id) the ratings are 2, 4, 3, which falls at the end, so excluded.)
