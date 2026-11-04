-- Typical mix: all four seasons, two products in one category (the category total decides, not any
-- single product). Rows are inserted Winter-first on purpose, so insertion order is not season order.
INSERT INTO products (product_id, product_name, category) VALUES
  (1, 'Parka',  'Outerwear'),
  (2, 'Coat',   'Outerwear'),
  (3, 'Sandal', 'Footwear'),
  (4, 'Boot',   'Footwear'),
  (5, 'Shorts', 'Apparel'),
  (6, 'Hat',    'Accessories');

INSERT INTO sales (sale_id, product_id, sale_date, quantity, price) VALUES
  (1,  1, '2023-01-15', 5,  100.00),  -- Winter, Outerwear: 5 * 100.00 = 500.00
  (2,  2, '2023-02-10', 3,   80.00),  -- Winter, Outerwear: 3 * 80.00 = 240.00
  (3,  4, '2023-01-20', 6,   60.00),  -- Winter, Footwear: 6 * 60.00 = 360.00
  (4,  3, '2023-04-05', 5,   30.00),  -- Spring, Footwear: 5 * 30.00 = 150.00
  (5,  4, '2023-05-05', 4,   60.00),  -- Spring, Footwear: 4 * 60.00 = 240.00
  (6,  5, '2023-03-10', 7,   20.00),  -- Spring, Apparel: 7 * 20.00 = 140.00
  (7,  6, '2023-07-04', 10,  15.50),  -- Summer, Accessories: 10 * 15.50 = 155.00
  (8,  5, '2023-08-08', 3,   20.00),  -- Summer, Apparel: 3 * 20.00 = 60.00
  (9,  1, '2023-10-10', 2,  100.00),  -- Fall, Outerwear: 2 * 100.00 = 200.00
  (10, 6, '2023-11-11', 1,   15.50);  -- Fall, Accessories: 1 * 15.50 = 15.50

-- expect: Fall,Outerwear,2,200.00 | Fall: Outerwear qty 2 beats Accessories qty 1
-- expect: Spring,Footwear,9,390.00 | Spring: Footwear is 5+4=9 units over two products (150.00+240.00); Apparel has 7, and no single Footwear product beats Shorts' 7, so ranking products instead of categories gets this wrong
-- expect: Summer,Accessories,10,155.00 | Summer: Accessories 10 units beat Apparel 3
-- expect: Winter,Outerwear,8,740.00 | Winter: Outerwear is 5+3=8 units (500.00+240.00) vs Footwear 6
