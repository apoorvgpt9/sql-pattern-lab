-- Index recommended in README "At scale" (b). The bench runs every solution without it, then with it.
-- (patient_id, result, test_date) is covering for all three solutions (no other test column is read):
--   01: each correlated MIN becomes a short covering lookup on (patient, result) instead of a
--       full table scan per patient (EXPLAIN: "Covering index lookup ... result='Positive'");
--   02: the window still sorts by patient_id, but reads the narrower index instead of the table;
--   03: the first-positive GROUP BY becomes a covering skip scan, and the join probes
--       (patient, 'Negative') in date order.
CREATE INDEX idx_tests_patient_result_date ON covid_tests (patient_id, result, test_date);
