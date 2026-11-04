-- Employees Qualified for Every Required Skill of a Role (original problem SPL-DIV-01): tables for MySQL 8.0.
-- The spec says skill matching is EXACT string equality. MySQL's default collation is case-insensitive and pads
-- trailing spaces, so both skill columns use utf8mb4_0900_bin (byte-for-byte comparison, no padding).
-- EmployeeSkills has no primary key: an exact duplicate (employee_id, skill) row is allowed.

CREATE TABLE EmployeeSkills (
  employee_id INT NOT NULL,
  skill       VARCHAR(100) COLLATE utf8mb4_0900_bin NOT NULL
);

CREATE TABLE RoleRequirements (
  role  VARCHAR(100) NOT NULL,
  skill VARCHAR(100) COLLATE utf8mb4_0900_bin NOT NULL,
  PRIMARY KEY (role, skill)          -- grain: one row per (role, required skill), unique
);
