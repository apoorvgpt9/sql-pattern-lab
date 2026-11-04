-- Department Highest Salary (LeetCode 184): tables for MySQL 8.0. Names mirror the original.
-- No foreign key, as on LeetCode: an employee may reference a department id that does not exist
-- (or have no department at all), and the query must cope with both.

CREATE TABLE Employee (
  id           INT PRIMARY KEY,   -- grain: one row per employee
  name         VARCHAR(100),
  salary       INT NOT NULL,      -- spec: nulls n/a, so salary is never NULL
  departmentId INT                -- logically FK Department.id; not enforced, may be NULL
);

CREATE TABLE Department (
  id   INT PRIMARY KEY,           -- grain: one row per department
  name VARCHAR(100) NOT NULL
);
