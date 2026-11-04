-- Equal consecutive ratings disqualify, even when the newest rating is above the oldest.
-- Fay (2,3,3) and Gus (3,3,4) end higher than they start but have a flat step; Hal (2,2,2) is flat all through.
INSERT INTO employees (employee_id, name) VALUES (1, 'Fay'), (2, 'Gus'), (3, 'Hal'), (4, 'Ivy');

INSERT INTO performance_reviews (review_id, employee_id, review_date, rating) VALUES
  (1,  1, '2024-01-01', 2), (2,  1, '2024-02-01', 3), (3,  1, '2024-03-01', 3),
  (4,  2, '2024-01-01', 3), (5,  2, '2024-02-01', 3), (6,  2, '2024-03-01', 4),
  (7,  3, '2024-01-01', 2), (8,  3, '2024-02-01', 2), (9,  3, '2024-03-01', 2),
  (10, 4, '2024-01-01', 1), (11, 4, '2024-02-01', 2), (12, 4, '2024-03-01', 3);

-- expect: 4,Ivy,2 | 1 < 2 < 3 is strictly increasing; score = 3 - 1 = 2. Fay, Gus and Hal each have an equal step and are excluded
