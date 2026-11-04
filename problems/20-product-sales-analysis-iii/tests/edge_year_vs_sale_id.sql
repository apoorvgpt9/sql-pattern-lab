-- sale_id runs in the OPPOSITE direction to the year, and years have gaps. "First" means smallest year,
-- not smallest sale_id and not the first row inserted.
INSERT INTO Sales (sale_id, product_id, year, quantity, price) VALUES
  (9, 5, 2001, 1, 1),
  (8, 5, 2005, 2, 2),
  (7, 5, 2010, 3, 3),
  (6, 6, 1999, 4, 4),
  (5, 6, 2012, 5, 5);

-- expect: 5,2001,1,1 | earliest year 2001 although its sale_id (9) is the largest of the product
-- expect: 6,1999,4,4 | earliest year 1999 although the 2012 row has the smaller sale_id (5)
