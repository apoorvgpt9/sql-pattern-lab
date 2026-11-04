-- Find Consistently Improving Employees (LeetCode 3580): tables for MySQL 8.0. Names mirror the original.
-- No foreign key, as on LeetCode: a review may reference an employee that is not in employees.

CREATE TABLE employees (
  employee_id INT PRIMARY KEY,   -- grain: one row per employee
  name        VARCHAR(100)
);

CREATE TABLE performance_reviews (
  review_id   INT PRIMARY KEY,   -- grain: one row per review
  employee_id INT,
  review_date DATE,
  rating      INT                -- 1-5
);
