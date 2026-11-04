-- Employees with 0, 1 and 2 reviews cannot qualify even when what they have rises (2 reviews: 2 -> 5).
-- Dov has exactly 3 reviews: the boundary that does qualify.
INSERT INTO employees (employee_id, name) VALUES
  (1, 'Ann'), (2, 'Ben'), (3, 'Cat'), (4, 'Dov');

INSERT INTO performance_reviews (review_id, employee_id, review_date, rating) VALUES
  (1, 1, '2024-01-01', 2), (2, 1, '2024-06-01', 5),                             -- Ann: two reviews, rising
  (3, 2, '2024-03-01', 4),                                                      -- Ben: one review
  (4, 4, '2024-01-01', 1), (5, 4, '2024-02-01', 2), (6, 4, '2024-03-01', 3);    -- Dov: exactly three, rising

-- expect: 4,Dov,2 | exactly 3 reviews, 1 < 2 < 3; score = 3 - 1 = 2. Ann (2 reviews), Ben (1), Cat (0) are excluded
