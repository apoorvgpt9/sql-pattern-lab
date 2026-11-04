-- breaks: edge_typical
-- MISTAKE: takes the highest price among the changes on or before the date instead of the most recent
-- one. Right whenever prices only go up; wrong as soon as a price drops.
SELECT product_id, MAX(new_price) AS price
FROM Products WHERE change_date <= '2019-08-16' GROUP BY product_id
UNION ALL
SELECT product_id, 10 FROM Products GROUP BY product_id HAVING MIN(change_date) > '2019-08-16';
