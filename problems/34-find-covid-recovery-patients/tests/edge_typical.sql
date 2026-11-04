-- Typical: two recovered patients, one still positive, one never positive, one never tested,
-- and tests for a patient_id that is not in patients.
INSERT INTO patients (patient_id, patient_name, age) VALUES
  (1, 'Alice', 30), (2, 'Bob', 45), (3, 'Cara', 50), (4, 'Dan', 60), (5, 'Eve', 25);

INSERT INTO covid_tests (test_id, patient_id, test_date, result) VALUES
  (1, 1, '2024-01-01', 'Positive'),
  (2, 1, '2024-01-11', 'Negative'),
  (3, 2, '2024-01-05', 'Positive'),
  (4, 2, '2024-01-08', 'Inconclusive'),   -- ignored: not a negative, does not reset anything
  (5, 2, '2024-01-12', 'Negative'),
  (6, 3, '2024-01-02', 'Positive'),       -- Cara never tests negative
  (7, 4, '2024-01-03', 'Negative'),       -- Dan never tests positive
  (8, 99, '2024-01-01', 'Positive'),      -- patient 99 is not in patients
  (9, 99, '2024-01-02', 'Negative');

-- expect: 2,Bob,45,7 | DATEDIFF('2024-01-12', '2024-01-05') = 7; the inconclusive 01-08 is skipped
-- expect: 1,Alice,30,10 | DATEDIFF('2024-01-11', '2024-01-01') = 10
