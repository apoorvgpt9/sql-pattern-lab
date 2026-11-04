-- Several positives and negatives. The anchor is the FIRST positive, and the end is the FIRST
-- negative after it - not the last positive, and not the last negative.
INSERT INTO patients (patient_id, patient_name, age) VALUES
  (1, 'Fay', 33), (2, 'Gus', 41);

INSERT INTO covid_tests (test_id, patient_id, test_date, result) VALUES
  (1, 1, '2024-02-01', 'Positive'),       -- Fay: anchor
  (2, 1, '2024-02-04', 'Negative'),       -- first negative after the anchor
  (3, 1, '2024-02-10', 'Positive'),       -- re-infection: irrelevant
  (4, 1, '2024-02-20', 'Negative'),
  (5, 2, '2024-02-01', 'Positive'),       -- Gus: anchor
  (6, 2, '2024-02-03', 'Positive'),       -- a second positive before any negative
  (7, 2, '2024-02-09', 'Negative'),       -- first negative after the anchor
  (8, 2, '2024-02-15', 'Negative');

-- expect: 1,Fay,33,3 | DATEDIFF('2024-02-04', '2024-02-01') = 3 (last positive 02-10 would give 10; last negative would give 19)
-- expect: 2,Gus,41,8 | DATEDIFF('2024-02-09', '2024-02-01') = 8 (last positive 02-03 would give 6; last negative would give 14)
