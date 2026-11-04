-- Find Overbooked Employees (LeetCode 3611): tables for MySQL 8.0. Names mirror the original.
-- No foreign key, as on LeetCode: a meeting may reference an employee_id not in employees.

CREATE TABLE employees (
  employee_id   INT PRIMARY KEY,    -- grain: one row per employee
  employee_name VARCHAR(100),
  department    VARCHAR(100)
);

CREATE TABLE meetings (
  meeting_id     INT PRIMARY KEY,   -- grain: one row per meeting
  employee_id    INT,
  meeting_date   DATE,
  meeting_type   VARCHAR(20),       -- 'Team' | 'Client' | 'Training'
  duration_hours DECIMAL(5,2)
);
