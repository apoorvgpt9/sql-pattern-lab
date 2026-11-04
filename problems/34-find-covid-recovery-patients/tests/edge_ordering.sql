-- Output order: recovery_time ASC, then patient_name ASC. Two patients tie on recovery_time;
-- patient_id runs opposite to name order, so sorting by id gives the wrong order.
INSERT INTO patients (patient_id, patient_name, age) VALUES
  (1, 'Zed', 70), (2, 'Max', 22), (3, 'Amy', 35);

INSERT INTO covid_tests (test_id, patient_id, test_date, result) VALUES
  (1, 1, '2024-05-01', 'Positive'), (2, 1, '2024-05-06', 'Negative'),
  (3, 2, '2024-05-10', 'Positive'), (4, 2, '2024-05-12', 'Negative'),
  (5, 3, '2024-05-03', 'Positive'), (6, 3, '2024-05-08', 'Negative');

-- expect: 2,Max,22,2 | DATEDIFF('2024-05-12', '2024-05-10') = 2: smallest recovery_time first
-- expect: 3,Amy,35,5 | DATEDIFF('2024-05-08', '2024-05-03') = 5; ties with Zed, 'Amy' < 'Zed'
-- expect: 1,Zed,70,5 | DATEDIFF('2024-05-06', '2024-05-01') = 5
