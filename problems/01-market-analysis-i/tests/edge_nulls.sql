-- NULLs: a user with no join_date, an order with no date, an order with no buyer.
-- The NULL buyer_id is what breaks a NOT IN (subquery) formulation.
INSERT INTO Users (user_id, join_date, favorite_brand) VALUES
  (1, NULL, 'Acme'),
  (2, '2019-05-05', NULL),
  (3, '2019-07-07', 'Initech');

INSERT INTO Orders (order_id, order_date, item_id, buyer_id, seller_id) VALUES
  (1, NULL,         1, 1,    2),     -- no date: not provably in 2019, not counted
  (2, '2019-06-06', 1, NULL, 2),     -- no buyer: belongs to nobody
  (3, '2019-06-07', 1, 2,    NULL),  -- no seller: irrelevant, counts for buyer 2
  (4, '2019-06-08', 1, 1,    2);

-- expect: 1,NULL,1 | order 4 counts, order 1 (NULL date) does not; NULL join_date is passed through
-- expect: 2,2019-05-05,1 | order 3
-- expect: 3,2019-07-07,0 | no orders; must survive even though a 2019 order has buyer_id NULL
