-- breaks: edge_price_ties, edge_full_tie_assumption
-- MISTAKE: gets MAX(price) and MIN(price) per store and joins back to inventory on price alone.
-- Fine without ties; on a price tie it matches every tied row, so a store yields several output rows
-- (and a store with one price for all products matches every product at both ends).
SELECT s.store_id, s.store_name, s.location, hi.product_name AS most_exp_product,
       lo.product_name AS cheapest_product, ROUND(lo.quantity / hi.quantity, 2) AS imbalance_ratio
FROM (SELECT store_id, MAX(price) AS max_p, MIN(price) AS min_p, COUNT(*) AS n
        FROM inventory GROUP BY store_id HAVING COUNT(*) >= 3) m
JOIN stores s    ON s.store_id = m.store_id
JOIN inventory hi ON hi.store_id = m.store_id AND hi.price = m.max_p
JOIN inventory lo ON lo.store_id = m.store_id AND lo.price = m.min_p
WHERE hi.quantity < lo.quantity
ORDER BY imbalance_ratio DESC, s.store_name;
