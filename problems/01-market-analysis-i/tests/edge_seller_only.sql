-- User 2 is active in 2019 only as a seller. User 1 also buys from themself once.
INSERT INTO Users (user_id, join_date, favorite_brand) VALUES
  (1, '2019-03-01', 'Acme'),
  (2, '2019-03-02', 'Globex');

INSERT INTO Orders (order_id, order_date, item_id, buyer_id, seller_id) VALUES
  (1, '2019-04-01', 7, 1, 1),  -- buyer = seller: one order, counted once
  (2, '2019-04-02', 7, 1, 2),
  (3, '2019-04-03', 8, 1, 2);

-- expect: 1,2019-03-01,3 | buyer of orders 1, 2, 3 (order 1 once, even though user 1 is also its seller)
-- expect: 2,2019-03-02,0 | seller of orders 2 and 3, never a buyer
