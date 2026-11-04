-- breaks: edge_typical, edge_boundary_date, edge_other_years
-- MISTAKE: finds each product's latest change overall, then asks whether it is on or before the date.
-- A product with changes both before and after the date has its overall-latest change AFTER the date,
-- so it is wrongly given the default instead of its price in effect on the date.
SELECT p.product_id,
       CASE WHEN l.last_date <= '2019-08-16' THEN p.new_price ELSE 10 END AS price
FROM Products p
JOIN (SELECT product_id, MAX(change_date) AS last_date FROM Products GROUP BY product_id) l
  ON l.product_id = p.product_id AND l.last_date = p.change_date;
