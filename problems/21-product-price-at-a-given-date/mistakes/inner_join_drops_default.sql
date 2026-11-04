-- breaks: edge_typical, edge_all_after, edge_boundary_date, edge_other_years
-- MISTAKE: only looks at changes on or before the date and never adds the default. A product whose
-- changes are all later has no qualifying row and silently disappears. (The spec's output grain is every
-- distinct product.)
SELECT p.product_id, p.new_price AS price
FROM Products p
JOIN (SELECT product_id, MAX(change_date) AS last_date
        FROM Products WHERE change_date <= '2019-08-16' GROUP BY product_id) l
  ON l.product_id = p.product_id AND l.last_date = p.change_date;
