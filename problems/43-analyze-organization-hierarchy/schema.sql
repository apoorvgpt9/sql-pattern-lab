-- Analyze Organization Hierarchy (LeetCode 3482): tables for MySQL 8.0. Names mirror the original.
-- No foreign key from manager_id to employee_id, as on LeetCode. The data has exactly one CEO
-- (manager_id NULL) and every other manager_id names an existing employee.

CREATE TABLE Employees (
  employee_id   INT PRIMARY KEY,   -- grain: one row per employee
  employee_name VARCHAR(100),
  manager_id    INT,               -- NULL for the CEO
  salary        INT,
  department    VARCHAR(100)
);
