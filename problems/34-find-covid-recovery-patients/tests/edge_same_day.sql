-- Boundary: a negative on the same day as the first positive is not "after" it (strictly later).
INSERT INTO patients (patient_id, patient_name, age) VALUES
  (1, 'Jay', 38), (2, 'Kim', 47);

INSERT INTO covid_tests (test_id, patient_id, test_date, result) VALUES
  (1, 1, '2024-04-01', 'Positive'),
  (2, 1, '2024-04-01', 'Negative'),       -- same day: does not count
  (3, 1, '2024-04-03', 'Negative'),
  (4, 2, '2024-04-01', 'Negative'),       -- Kim: same-day pair only (test_id order reversed on purpose)
  (5, 2, '2024-04-01', 'Positive');

-- expect: 1,Jay,38,2 | the same-day negative is skipped; DATEDIFF('2024-04-03', '2024-04-01') = 2
-- (no row for Kim: her only negative is on the day of her positive)
