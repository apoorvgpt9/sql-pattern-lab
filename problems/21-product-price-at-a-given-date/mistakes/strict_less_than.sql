-- breaks: edge_boundary_date
-- MISTAKE: uses change_date < '2019-08-16'. A change dated exactly on the target date is in effect that
-- day, so it must be included; here it is treated as "not yet", and the previous price (or the default) is returned.
SELECT p.product_id, p.new_price AS price
FROM Products p
JOIN (SELECT product_id, MAX(change_date) AS last_date
        FROM Products WHERE change_date < '2019-08-16' GROUP BY product_id) l
  ON l.product_id = p.product_id AND l.last_date = p.change_date
UNION ALL
SELECT product_id, 10 FROM Products GROUP BY product_id HAVING MIN(change_date) >= '2019-08-16';
