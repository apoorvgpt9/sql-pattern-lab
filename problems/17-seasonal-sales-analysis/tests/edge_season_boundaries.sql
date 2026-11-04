-- Every season boundary day, a leap day, and a Winter that spans two calendar years. Each
-- boundary sale is sized so that putting it in the wrong season changes some winner or total.
-- 'Early' and 'Late' are two categories; every price is 1.00 so revenue equals quantity.
INSERT INTO products (product_id, product_name, category) VALUES
  (1, 'p-early', 'Early'),
  (2, 'p-late',  'Late');

INSERT INTO sales (sale_id, product_id, sale_date, quantity, price) VALUES
  (1,  2, '2023-09-01', 4, 1.00),  -- first day of Fall
  (2,  1, '2023-11-30', 1, 1.00),  -- last day of Fall
  (3,  2, '2023-12-01', 2, 1.00),  -- first day of Winter
  (4,  2, '2023-12-31', 2, 1.00),  -- Winter, still year 2023
  (5,  2, '2024-01-01', 2, 1.00),  -- Winter, now year 2024: same bucket as December
  (6,  1, '2024-02-29', 5, 1.00),  -- leap day: last day of Winter
  (7,  2, '2024-03-01', 1, 1.00),  -- first day of Spring (day after the leap day)
  (8,  1, '2023-05-31', 3, 1.00),  -- last day of Spring
  (9,  2, '2023-06-01', 4, 1.00),  -- first day of Summer
  (10, 1, '2023-08-31', 5, 1.00);  -- last day of Summer

-- expect: Fall,Late,4,4.00 | Fall = Sep 1 (Late 4) .. Nov 30 (Early 1): Late wins with 4
-- expect: Spring,Early,3,3.00 | Spring = Mar 1 (Late 1) and May 31 (Early 3): Early wins with 3; the leap day (Feb 29) must not be in here
-- expect: Summer,Early,5,5.00 | Summer = Jun 1 (Late 4) and Aug 31 (Early 5): Early wins with 5
-- expect: Winter,Late,6,6.00 | Winter = Dec 1, Dec 31, Jan 1 (Late 2+2+2, spread over two years, ignored) vs Feb 29 (Early 5): Late 6 wins, in ONE row
