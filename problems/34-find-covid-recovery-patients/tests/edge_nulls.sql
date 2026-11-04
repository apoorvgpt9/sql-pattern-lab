-- NULLs (README "Assumptions"): a test with no date cannot be placed in time, so it is ignored.
-- A NULL age is passed through.
INSERT INTO patients (patient_id, patient_name, age) VALUES
  (1, 'Lea', NULL), (2, 'Ned', 61), (3, 'Ola', 44);

INSERT INTO covid_tests (test_id, patient_id, test_date, result) VALUES
  (1, 1, '2024-05-01', 'Positive'),
  (2, 1, '2024-05-04', 'Negative'),
  (3, 2, NULL,         'Positive'),       -- Ned: undated positive, ignored (ORDER BY test_date puts it FIRST in MySQL)
  (4, 2, '2024-05-10', 'Positive'),       -- so this is the first positive
  (5, 2, '2024-05-12', 'Negative'),
  (6, 3, '2024-05-01', 'Positive'),
  (7, 3, NULL,         'Negative');       -- Ola: undated negative is not "after" anything

-- expect: 2,Ned,61,2 | anchor 05-10 (the NULL-dated positive is ignored); DATEDIFF('2024-05-12', '2024-05-10') = 2
-- expect: 1,Lea,NULL,3 | DATEDIFF('2024-05-04', '2024-05-01') = 3; NULL age passed through
