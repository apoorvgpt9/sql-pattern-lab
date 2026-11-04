-- Index recommended in README "At scale" (b). The bench runs every solution without it, then with it.
-- (visited_on, amount) is covering for all three solutions: the daily GROUP BY can stream in date order
-- without a temporary table, and the raw-row RANGE window of approach 2 reads the index in order.
CREATE INDEX idx_customer_visited_amount ON Customer (visited_on, amount);
