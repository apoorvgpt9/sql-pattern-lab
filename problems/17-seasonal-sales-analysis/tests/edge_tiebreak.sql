-- The three-level rule: Summer ties on quantity (revenue decides, and the revenue winner is the
-- alphabetically LATER category); Fall has the higher revenue but lower quantity (quantity decides);
-- Spring ties on quantity AND revenue across three categories (alphabetical decides).
INSERT INTO products (product_id, product_name, category) VALUES
  (1, 'p1', 'Books'),
  (2, 'p2', 'Toys'),
  (3, 'p3', 'Games'),
  (4, 'p4', 'Garden'),
  (5, 'p5', 'Zoo'),
  (6, 'p6', 'Art');

INSERT INTO sales (sale_id, product_id, sale_date, quantity, price) VALUES
  (1,  1, '2023-06-10', 4, 3.00),   -- Summer Books: 4 * 3.00 = 12.00
  (2,  1, '2023-07-10', 6, 3.00),   -- Summer Books: 6 * 3.00 = 18.00 -> 10 units, 30.00
  (3,  2, '2023-08-01', 10, 5.00),  -- Summer Toys: 10 units, 50.00
  (4,  1, '2023-09-15', 8, 10.00),  -- Fall Books: 8 * 10.00 = 80.00
  (5,  2, '2023-10-20', 9, 1.00),   -- Fall Toys: 9 * 1.00 = 9.00
  (6,  3, '2023-03-15', 4, 2.50),   -- Spring Games: 4 * 2.50 = 10.00
  (7,  4, '2023-04-01', 1, 4.00),   -- Spring Garden: 1 * 4.00 = 4.00
  (8,  4, '2023-04-02', 3, 2.00),   -- Spring Garden: 3 * 2.00 = 6.00 -> 4 units, 10.00
  (9,  5, '2023-05-05', 4, 2.50),   -- Spring Zoo: 4 * 2.50 = 10.00
  (10, 6, '2023-01-10', 3, 1.00),   -- Winter Art: 3 * 1.00 = 3.00
  (11, 5, '2023-02-10', 3, 1.00);   -- Winter Zoo: 3 * 1.00 = 3.00

-- expect: Fall,Toys,9,9.00 | Fall: Toys sold 9 units, Books 8 units; quantity decides first, so Toys wins despite Books' 80.00 revenue
-- expect: Spring,Games,4,10.00 | Spring: Games, Garden and Zoo all have 4 units and 10.00 (Garden's 4.00+6.00 split over two sales); the alphabetically smallest, Games, wins ('Gam' < 'Gar')
-- expect: Summer,Toys,10,50.00 | Summer: Books and Toys tie at 10 units; Toys has revenue 50.00 vs 30.00, and wins even though 'Books' sorts first
-- expect: Winter,Art,3,3.00 | Winter: Art and Zoo tie at 3 units and 3.00; Art is alphabetically first
