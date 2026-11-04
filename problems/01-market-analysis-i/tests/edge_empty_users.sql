-- Users is empty while Orders is not. The output grain is Users, so the result is empty.
-- A query driven from Orders returns rows here.
INSERT INTO Orders (order_id, order_date, item_id, buyer_id, seller_id) VALUES
  (1, '2019-02-02', 1, 5, 6),
  (2, '2019-03-03', 1, 5, 6);

-- expect-empty: no Users rows, and orders by unknown buyers never create users
