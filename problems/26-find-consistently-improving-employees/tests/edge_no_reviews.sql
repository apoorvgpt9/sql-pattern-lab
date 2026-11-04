-- Employees exist but there are no reviews at all.
INSERT INTO employees (employee_id, name) VALUES (1, 'Nia'), (2, 'Oz');

-- expect-empty: no reviews, so nobody has 3 reviews
