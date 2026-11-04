-- Products with a single row, a product whose rows are all in one year, and sale_id 1 reused for a
-- different product in a different year (legal: the key is (sale_id, year)). A join back on sale_id
-- alone would mix them up.
INSERT INTO Sales (sale_id, product_id, year, quantity, price) VALUES
  (1, 10, 2015, 3, 30),
  (1, 11, 2016, 4, 40),
  (2, 11, 2017, 5, 50),
  (3, 12, 2018, 6, 60),
  (4, 12, 2018, 7, 70);

-- expect: 10,2015,3,30 | single row, trivially its own first year
-- expect: 11,2016,4,40 | first year 2016; sale_id 1 is also used by product 10 in 2015, which must not interfere
-- expect: 12,2018,6,60 | both rows of product 12 are in its only (hence first) year
-- expect: 12,2018,7,70 | same
