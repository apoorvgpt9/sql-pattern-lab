-- Orders on the first and last day of 2019 and on the days just outside it.
-- User 2 has buyer orders, but none in 2019: the case that a WHERE filter on Orders deletes.
INSERT INTO Users (user_id, join_date, favorite_brand) VALUES
  (1, '2018-06-01', 'Acme'),
  (2, '2018-06-02', 'Globex'),
  (3, '2018-06-03', 'Initech');

INSERT INTO Orders (order_id, order_date, item_id, buyer_id, seller_id) VALUES
  (1, '2018-12-31', 1, 1, 2),  -- one day before 2019
  (2, '2019-01-01', 1, 1, 2),  -- first day of 2019: counts
  (3, '2019-12-31', 1, 1, 3),  -- last day of 2019: counts
  (4, '2020-01-01', 1, 2, 1),  -- one day after 2019
  (5, '2018-12-31', 1, 2, 3);  -- one day before 2019

-- expect: 1,2018-06-01,2 | orders 2 and 3 are inside 2019 inclusive; order 1 is 2018-12-31
-- expect: 2,2018-06-02,0 | buys only on 2018-12-31 and 2020-01-01, so 0 - but the row must exist
-- expect: 3,2018-06-03,0 | never a buyer (only seller of orders 3 and 5)
