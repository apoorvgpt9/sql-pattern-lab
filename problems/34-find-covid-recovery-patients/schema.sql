-- Find COVID Recovery Patients (LeetCode 3586): tables for MySQL 8.0. Names mirror the original.
-- No foreign key, as on LeetCode: a test may reference a patient_id that is not in patients.

CREATE TABLE patients (
  patient_id   INT PRIMARY KEY,     -- grain: one row per patient
  patient_name VARCHAR(100),
  age          INT
);

CREATE TABLE covid_tests (
  test_id    INT PRIMARY KEY,       -- grain: one row per test
  patient_id INT,
  test_date  DATE,
  result     VARCHAR(20)            -- 'Positive' | 'Negative' | 'Inconclusive'
);
