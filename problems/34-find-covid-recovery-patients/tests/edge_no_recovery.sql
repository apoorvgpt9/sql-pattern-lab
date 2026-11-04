-- Nobody recovers: positives followed only by inconclusive results, and a negative that comes
-- before the positive.
INSERT INTO patients (patient_id, patient_name, age) VALUES
  (1, 'Pia', 31), (2, 'Quinn', 58);

INSERT INTO covid_tests (test_id, patient_id, test_date, result) VALUES
  (1, 1, '2024-06-01', 'Positive'),
  (2, 1, '2024-06-05', 'Inconclusive'),   -- not a negative
  (3, 2, '2024-06-01', 'Negative'),
  (4, 2, '2024-06-02', 'Inconclusive'),
  (5, 2, '2024-06-03', 'Positive');

-- expect-empty: Pia has no negative at all; Quinn's only negative (06-01) is before her positive (06-03)
