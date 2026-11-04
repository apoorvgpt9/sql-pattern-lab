-- The week Monday 2024-12-30 .. Sunday 2025-01-05 crosses a year boundary but is ONE week.
-- Grouping by (YEAR(d), WEEK(d, 1)) splits it into (2024, 53) and (2025, 1).
INSERT INTO employees (employee_id, employee_name, department) VALUES
  (1, 'Eli', 'Finance');

INSERT INTO meetings (meeting_id, employee_id, meeting_date, meeting_type, duration_hours) VALUES
  (1, 1, '2024-12-30', 'Client', 11.00),   -- Monday, still 2024
  (2, 1, '2025-01-02', 'Team',   10.00),   -- Thursday, 2025, same week -> 21, heavy
  (3, 1, '2025-01-06', 'Client', 22.00);   -- next Monday's week: 22, heavy

-- expect: 1,Eli,Finance,2 | week 2024-12-30: 11 + 10 = 21; week 2025-01-06: 22
