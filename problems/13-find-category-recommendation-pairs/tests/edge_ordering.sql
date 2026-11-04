-- Ordering: customer_count DESC, category1 ASC, category2 ASC, with category1 < category2 alphabetically.
-- Product ids run opposite to the alphabet (Zebra=1 ... Apple=3), so id order is not category order.
INSERT INTO ProductInfo (product_id, category, price) VALUES
  (1, 'Zebra', 1.00), (2, 'Yarn', 2.00), (3, 'Apple', 3.00), (4, 'Mango', 4.00);

INSERT INTO ProductPurchases (user_id, product_id, quantity) VALUES
  (1, 1, 1), (1, 2, 1), (1, 3, 1), (1, 4, 1),
  (2, 1, 1), (2, 2, 1), (2, 3, 1), (2, 4, 1),
  (3, 1, 1), (3, 2, 1), (3, 3, 1), (3, 4, 1),
  (4, 1, 1), (4, 4, 1);   -- customer 4 buys only Zebra and Mango

-- expect: Mango,Zebra,4 | customers 1-4: the only 4-customer pair, so first; reported as (Mango, Zebra) since 'Mango' < 'Zebra'
-- expect: Apple,Mango,3 | customers 1-3; of the five 3-customer pairs, smallest category1 and then smallest category2
-- expect: Apple,Yarn,3 | same category1 'Apple': 'Yarn' > 'Mango'
-- expect: Apple,Zebra,3 | same category1 'Apple': 'Zebra' is the largest category2; it comes BEFORE (Mango,Yarn) because category1 is the first key
-- expect: Mango,Yarn,3 | category1 'Mango' sorts after 'Apple' (sorting by category2 first would put this before Apple,Zebra)
-- expect: Yarn,Zebra,3 | last
