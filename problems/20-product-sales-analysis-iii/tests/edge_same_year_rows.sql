-- Several rows in the first year: ALL are returned. Sales 1 and 3 are identical except for sale_id, so
-- the output contains the same row twice (duplicates are kept: DISTINCT or GROUP BY would merge them).
INSERT INTO Sales (sale_id, product_id, year, quantity, price) VALUES
  (1, 1, 2020, 5,  10),
  (2, 1, 2020, 7,  10),
  (3, 1, 2020, 5,  10),
  (4, 1, 2021, 99, 99),
  (5, 2, 2019, 1,  1);

-- expect: 1,2020,5,10 | first-year row of product 1 (sale 1)
-- expect: 1,2020,7,10 | another first-year row (sale 2): all rows of the first year are returned, not one per product
-- expect: 1,2020,5,10 | identical to sale 1 apart from sale_id: the row appears twice in the output
-- expect: 2,2019,1,1 | single-row product
-- (product 1's 2021 row is later and is dropped.)
