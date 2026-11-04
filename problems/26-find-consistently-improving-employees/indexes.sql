-- Index recommended in README "At scale" (b). The bench runs every solution without it, then with it.
-- (employee_id, review_date, rating) is covering for all three solutions (review_id is the InnoDB primary key,
-- so it is carried in every secondary index entry and the tie-break needs no table lookup):
--   01: each correlated COUNT becomes a covering index range read of one employee's newer reviews;
--   02/03: the window scan reads the narrow index instead of the whole table. (On 100k generated rows EXPLAIN
--          still showed a sort for the window, ascending or descending index, so do not expect the sort to vanish.)
CREATE INDEX idx_reviews_emp_date_rating ON performance_reviews (employee_id, review_date, rating);
