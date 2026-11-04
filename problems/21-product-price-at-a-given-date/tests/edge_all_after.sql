-- Every product only has changes after the target date: all prices are the default 10, and every
-- product still appears. Nothing on or before the date exists in the table at all.
INSERT INTO Products (product_id, new_price, change_date) VALUES
  (1, 5, '2019-08-17'),
  (1, 6, '2019-09-01'),
  (2, 7, '2020-01-01');

-- expect: 1,10 | two later changes, none in effect yet
-- expect: 2,10 | same
