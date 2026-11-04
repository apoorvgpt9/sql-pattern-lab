-- Approach 1: split the products in two groups and UNION them. (a) products with a change on or before
-- the date: join to each one's latest such change date; (b) products with no such change: price 10.
-- The classic textbook answer: correct, but reads the table three times.
SELECT p.product_id, p.new_price AS price
FROM Products p
JOIN (SELECT product_id, MAX(change_date) AS last_date
        FROM Products
       WHERE change_date <= '2019-08-16'
       GROUP BY product_id) l
  ON l.product_id = p.product_id AND l.last_date = p.change_date
UNION ALL
SELECT product_id, 10 AS price
FROM Products
GROUP BY product_id
HAVING MIN(change_date) > '2019-08-16';
