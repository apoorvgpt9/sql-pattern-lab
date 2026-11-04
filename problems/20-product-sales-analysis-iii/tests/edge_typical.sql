-- Typical mix: products whose first year is in different years, products with later years that must be
-- dropped, and a product whose earlier-year row has a LARGER sale_id than its later-year row
-- (so "first" cannot be read off sale_id). The table's overall earliest year (2008) belongs to one product only.
INSERT INTO Sales (sale_id, product_id, year, quantity, price) VALUES
  (1, 100, 2008, 10, 5000),
  (2, 100, 2009, 12, 5000),
  (7, 200, 2011, 15, 9000),
  (3, 200, 2012, 15, 9000),
  (4, 300, 2009, 4,  100),
  (5, 300, 2010, 8,  150),
  (6, 300, 2010, 9,  160);

-- expect: 100,2008,10,5000 | product 100 first appears in 2008; its 2009 row is later
-- expect: 200,2011,15,9000 | first year 2011 (sale_id 7), although the 2012 row has the smaller sale_id 3
-- expect: 300,2009,4,100 | first year 2009; the two 2010 rows are later
