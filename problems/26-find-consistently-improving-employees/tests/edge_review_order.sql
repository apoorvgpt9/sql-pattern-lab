-- review_id order is NOT date order. Jo's ids rise while the dates fall; Kim's ids fall while the dates rise.
-- Chronology must come from review_date.
INSERT INTO employees (employee_id, name) VALUES (1, 'Jo'), (2, 'Kim');

INSERT INTO performance_reviews (review_id, employee_id, review_date, rating) VALUES
  (1, 1, '2024-03-01', 5), (2, 1, '2024-02-01', 3), (3, 1, '2024-01-01', 1),  -- by id: 5,3,1; by date: 1,3,5
  (6, 2, '2024-01-01', 3), (5, 2, '2024-02-01', 2), (4, 2, '2024-03-01', 1);  -- by id: 1,2,3; by date: 3,2,1

-- expect: 1,Jo,4 | by review_date the ratings are 1,3,5 (strictly rising); score = 5 - 1 = 4
-- (Kim: by review_date 3,2,1 falls, although by review_id it would look like 1,2,3, so excluded.)
