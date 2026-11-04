-- Tests the output ORDER: season ascending as a string (Fall, Spring, Summer, Winter).
-- Quantity rises in the opposite direction (Fall 10 < Spring 20 < Summer 30 < Winter 40) and the
-- calendar order starting at Winter would be yet another order, so neither can pass by accident.
INSERT INTO products (product_id, product_name, category) VALUES
  (1, 'p1', 'Only');

INSERT INTO sales (sale_id, product_id, sale_date, quantity, price) VALUES
  (1, 1, '2023-01-15', 40, 1.00),  -- Winter: 40 * 1.00 = 40.00
  (2, 1, '2023-04-15', 20, 2.00),  -- Spring: 20 * 2.00 = 40.00
  (3, 1, '2023-07-15', 30, 1.00),  -- Summer: 30 * 1.00 = 30.00
  (4, 1, '2023-10-15', 10, 9.00);  -- Fall: 10 * 9.00 = 90.00

-- expect: Fall,Only,10,90.00 | first in string order although it has the fewest units
-- expect: Spring,Only,20,40.00 | second in string order
-- expect: Summer,Only,30,30.00 | third
-- expect: Winter,Only,40,40.00 | last in string order although it has the most units
