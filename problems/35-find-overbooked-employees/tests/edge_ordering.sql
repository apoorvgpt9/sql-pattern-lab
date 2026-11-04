-- Output order: meeting_heavy_weeks DESC, then employee_name ASC. Ada and Zoe tie on 2;
-- employee_id runs opposite to name order. 2024-05-06, 05-13, 05-20 are Mondays.
INSERT INTO employees (employee_id, employee_name, department) VALUES
  (1, 'Zoe', 'Eng'), (2, 'Ada', 'Eng'), (3, 'Kim', 'Ops');

INSERT INTO meetings (meeting_id, employee_id, meeting_date, meeting_type, duration_hours) VALUES
  (1, 1, '2024-05-06', 'Team', 21.00), (2, 1, '2024-05-13', 'Team', 21.00),
  (3, 2, '2024-05-06', 'Team', 21.00), (4, 2, '2024-05-20', 'Team', 21.00),
  (5, 3, '2024-05-06', 'Team', 21.00), (6, 3, '2024-05-13', 'Team', 21.00),
  (7, 3, '2024-05-20', 'Team', 21.00);

-- expect: 3,Kim,Ops,3 | three heavy weeks (21 each): most first
-- expect: 2,Ada,Eng,2 | two heavy weeks; ties with Zoe, 'Ada' < 'Zoe'
-- expect: 1,Zoe,Eng,2 | two heavy weeks
