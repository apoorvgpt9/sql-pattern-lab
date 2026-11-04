-- Departments exist, Employee is empty.
INSERT INTO Department (id, name) VALUES (1, 'IT'), (2, 'Sales');

-- expect-empty: no employees, so no department has any top salaries
