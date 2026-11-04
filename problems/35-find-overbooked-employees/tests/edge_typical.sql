-- Typical: hours are summed per Monday-Sunday week; a week is heavy above 20 hours; an employee
-- needs at least 2 heavy weeks. 2024-01-08, 01-15, 01-22, 01-29 are Mondays.
INSERT INTO employees (employee_id, employee_name, department) VALUES
  (1, 'Ann', 'Eng'), (2, 'Raj', 'Sales'), (3, 'Liu', 'Ops'), (4, 'Moe', 'Eng');

INSERT INTO meetings (meeting_id, employee_id, meeting_date, meeting_type, duration_hours) VALUES
  (1,  1, '2024-01-08', 'Team',     12.00),
  (2,  1, '2024-01-10', 'Client',   10.00),   -- Ann, week 01-08: 12 + 10 = 22 > 20, heavy
  (3,  1, '2024-01-15', 'Team',      8.00),
  (4,  1, '2024-01-16', 'Training',  8.00),
  (5,  1, '2024-01-16', 'Client',    5.00),   -- same day twice; week 01-15: 8 + 8 + 5 = 21, heavy
  (6,  1, '2024-01-22', 'Team',     10.00),   -- week 01-22: 10, not heavy
  (7,  2, '2024-01-09', 'Client',   25.00),   -- Raj: one heavy week only
  (8,  4, '2024-01-08', 'Team',     20.50),
  (9,  4, '2024-01-15', 'Team',     20.50),
  (10, 4, '2024-01-29', 'Team',     20.50),   -- Moe: three weeks of 20.5, all heavy
  (11, 99, '2024-01-08', 'Team',    30.00),
  (12, 99, '2024-01-15', 'Team',    30.00);   -- employee 99 is not in employees

-- expect: 4,Moe,Eng,3 | weeks 01-08, 01-15, 01-29 each 20.5 > 20: 3 heavy weeks, listed first
-- expect: 1,Ann,Eng,2 | weeks 01-08 (22) and 01-15 (21) are heavy; 01-22 (10) is not
