-- NULLs: a meeting with no duration adds nothing (SUM skips NULL); a NULL department passes through.
-- 2024-04-01, 04-08, 04-15 are Mondays.
INSERT INTO employees (employee_id, employee_name, department) VALUES
  (1, 'Gil', NULL), (2, 'Hana', 'Eng');

INSERT INTO meetings (meeting_id, employee_id, meeting_date, meeting_type, duration_hours) VALUES
  (1, 1, '2024-04-01', 'Team',   21.00),   -- Gil, week 04-01: heavy
  (2, 1, '2024-04-08', 'Team',   15.00),
  (3, 1, '2024-04-09', 'Client',  NULL),   -- unknown duration: week 04-08 stays at 15
  (4, 1, '2024-04-15', 'Team',   22.00),   -- week 04-15: heavy
  (5, 2, '2024-04-01', 'Team',   21.00),   -- Hana, week 04-01: heavy
  (6, 2, '2024-04-08', 'Client',  NULL);   -- week 04-08: SUM of only NULL is NULL, not heavy

-- expect: 1,Gil,NULL,2 | weeks 04-01 (21) and 04-15 (22); week 04-08 = 15 (the NULL adds nothing)
