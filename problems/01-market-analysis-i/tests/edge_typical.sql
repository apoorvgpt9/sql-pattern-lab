-- Typical mix: several 2019 buyer orders, orders in other years, a seller-only user,
-- two orders that look identical except for order_id, and an order from a buyer not in Users.
INSERT INTO Users (user_id, join_date, favorite_brand) VALUES
  (10, '2018-03-15', 'Acme'),
  (11, '2019-06-01', 'Globex'),
  (12, '2017-11-30', 'Initech'),
  (13, '2019-01-20', 'Acme');

INSERT INTO Items (item_id, item_brand) VALUES
  (100, 'Acme'), (101, 'Globex'), (102, 'Initech');

INSERT INTO Orders (order_id, order_date, item_id, buyer_id, seller_id) VALUES
  (1, '2019-02-10', 100, 10, 11),
  (2, '2019-07-04', 101, 10, 12),
  (3, '2019-07-04', 101, 10, 12),  -- same day, item and seller as order 2: still a separate order
  (4, '2020-03-01', 102, 10, 11),  -- 2020: not counted
  (5, '2019-05-05', 100, 11, 10),
  (6, '2018-09-09', 102, 12, 10),  -- 2018: not counted
  (7, '2019-10-10', 100, 13, 12),
  (8, '2019-11-11', 101, 99, 12);  -- buyer 99 is not a user: must not create an output row

-- expect: 10,2018-03-15,3 | orders 1, 2, 3 are 2019 buys by user 10 (2 and 3 both count); order 4 is 2020
-- expect: 11,2019-06-01,1 | order 5; user 11 is also seller of orders 1 and 4, which must not count
-- expect: 12,2017-11-30,0 | only 2019 activity is selling (orders 2, 3, 7, 8); their one buy (6) is 2018
-- expect: 13,2019-01-20,1 | order 7
-- (no row for buyer 99: output grain is Users, and 99 is not in Users)
