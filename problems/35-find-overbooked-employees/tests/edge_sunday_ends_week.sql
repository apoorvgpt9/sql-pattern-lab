-- Weeks run Monday to Sunday: a Sunday belongs with the Monday six days BEFORE it.
-- 2024-03-04 and 2024-03-18 are Mondays; 03-10 and 03-24 are Sundays.
-- With Sunday-start weeks (MySQL WEEK() default mode 0) each pair is split and nothing is heavy.
INSERT INTO employees (employee_id, employee_name, department) VALUES
  (1, 'Dee', 'Support');

INSERT INTO meetings (meeting_id, employee_id, meeting_date, meeting_type, duration_hours) VALUES
  (1, 1, '2024-03-04', 'Team',   10.00),
  (2, 1, '2024-03-10', 'Client', 11.00),   -- Sunday: same week as 03-04 -> 21, heavy
  (3, 1, '2024-03-18', 'Team',   11.00),
  (4, 1, '2024-03-24', 'Client', 10.00);   -- Sunday: same week as 03-18 -> 21, heavy

-- expect: 1,Dee,Support,2 | week 03-04..03-10 = 10 + 11 = 21 and week 03-18..03-24 = 11 + 10 = 21
