-- Ordering: customer_count DESC, then product1_id ASC, then product2_id ASC.
-- Product ids are deliberately not 1..n. Users 1-3 buy all four products; user 4 buys only 9 and 12.
INSERT INTO ProductInfo (product_id, category, price) VALUES
  (5, 'A-cat', 1.00), (7, 'B-cat', 2.00), (9, 'C-cat', 3.00), (12, 'D-cat', 4.00);

INSERT INTO ProductPurchases (user_id, product_id, quantity) VALUES
  (1, 5, 1), (1, 7, 1), (1, 9, 1), (1, 12, 1),
  (2, 5, 1), (2, 7, 1), (2, 9, 1), (2, 12, 1),
  (3, 5, 1), (3, 7, 1), (3, 9, 1), (3, 12, 1),
  (4, 9, 1), (4, 12, 1);

-- expect: 9,12,C-cat,D-cat,4 | users 1, 2, 3, 4: the only 4-customer pair, so first although it has the largest ids
-- expect: 5,7,A-cat,B-cat,3 | users 1-3; of the five 3-customer pairs it has the smallest product1_id, then the smallest product2_id
-- expect: 5,9,A-cat,C-cat,3 | same product1_id as the previous row: product2_id 9 < 12
-- expect: 5,12,A-cat,D-cat,3 | product2_id 12 comes after 9
-- expect: 7,9,B-cat,C-cat,3 | product1_id 7 comes after all the 5-rows
-- expect: 7,12,B-cat,D-cat,3 | last
