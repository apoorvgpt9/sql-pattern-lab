-- ASSUMPTION test (README "Assumptions"): heavy means MORE than 20 hours, so exactly 20.00 is not
-- heavy. 2024-02-05, 02-12, 02-19 are Mondays.
INSERT INTO employees (employee_id, employee_name, department) VALUES
  (1, 'Bea', 'Legal'), (2, 'Cal', 'Legal');

INSERT INTO meetings (meeting_id, employee_id, meeting_date, meeting_type, duration_hours) VALUES
  (1, 1, '2024-02-05', 'Client', 12.50),
  (2, 1, '2024-02-07', 'Team',    7.50),   -- Bea, week 02-05: 12.5 + 7.5 = 20.00, NOT heavy
  (3, 1, '2024-02-12', 'Client', 20.25),   -- week 02-12: 20.25, heavy
  (4, 1, '2024-02-19', 'Client', 20.50),   -- week 02-19: 20.50, heavy
  (5, 2, '2024-02-05', 'Team',   20.00),   -- Cal, week 02-05: 20.00, not heavy
  (6, 2, '2024-02-12', 'Team',   20.01);   -- week 02-12: 20.01, heavy (only one)

-- expect: 1,Bea,Legal,2 | weeks 02-12 (20.25) and 02-19 (20.50); 02-05 sums to exactly 20.00, not > 20
