-- Negatives before the first positive are irrelevant. They must neither count as the recovery
-- nor stop a later negative from counting.
INSERT INTO patients (patient_id, patient_name, age) VALUES
  (1, 'Hal', 52), (2, 'Ivy', 29);

INSERT INTO covid_tests (test_id, patient_id, test_date, result) VALUES
  (1, 1, '2024-03-01', 'Negative'),       -- Hal: before any positive, ignored
  (2, 1, '2024-03-05', 'Positive'),
  (3, 1, '2024-03-08', 'Negative'),
  (4, 2, '2024-03-01', 'Negative'),       -- Ivy: only a negative BEFORE the positive
  (5, 2, '2024-03-05', 'Positive');

-- expect: 1,Hal,52,3 | DATEDIFF('2024-03-08', '2024-03-05') = 3; the 03-01 negative is before the anchor
-- (no row for Ivy: no negative after 2024-03-05)
