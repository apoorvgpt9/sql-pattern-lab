-- Nobody qualifies: one heavy week and one week of exactly 20 hours (not heavy under > 20).
-- 2024-06-03 and 06-10 are Mondays.
INSERT INTO employees (employee_id, employee_name, department) VALUES
  (1, 'Ivy', 'Eng');

INSERT INTO meetings (meeting_id, employee_id, meeting_date, meeting_type, duration_hours) VALUES
  (1, 1, '2024-06-03', 'Client', 25.00),   -- heavy
  (2, 1, '2024-06-10', 'Team',   10.00),
  (3, 1, '2024-06-14', 'Team',   10.00);   -- week 06-10: exactly 20.00, not heavy

-- expect-empty: Ivy has one heavy week (06-03); week 06-10 totals 20.00, which is not more than 20
