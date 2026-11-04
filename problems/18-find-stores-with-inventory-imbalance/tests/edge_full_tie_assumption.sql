-- ASSUMPTION (README "Assumptions"): if price AND quantity both tie, the reference rule is silent;
-- we break the tie by product_name ASC so the answer is deterministic.
-- Twins: 'alpha' and 'beta' tie fully at the top (10.00, 3 units); 'gamma' and 'delta' tie fully at the bottom (1.00, 5 units).
INSERT INTO stores (store_id, store_name, location) VALUES
  (30, 'Twins', 'T');

INSERT INTO inventory (inventory_id, store_id, product_name, quantity, price) VALUES
  (1, 30, 'beta',  3, 10.00),
  (2, 30, 'alpha', 3, 10.00),
  (3, 30, 'gamma', 5, 1.00),
  (4, 30, 'delta', 5, 1.00);

-- expect: 30,Twins,T,alpha,delta,1.67 | top tie resolved to 'alpha' (before 'beta'), bottom tie to 'delta' (before 'gamma'); 3 < 5, ratio 5/3 = 1.6667 -> 1.67
