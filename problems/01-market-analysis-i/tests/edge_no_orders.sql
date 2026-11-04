-- Orders is empty. Every user must still appear, with a count of 0 (an INNER JOIN returns nothing).
INSERT INTO Users (user_id, join_date, favorite_brand) VALUES
  (1, '2019-01-01', 'Acme'),
  (2, '2019-01-02', 'Globex');

-- expect: 1,2019-01-01,0 | no orders exist at all; the user row survives with 0, not NULL
-- expect: 2,2019-01-02,0 | same
