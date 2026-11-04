-- Products exist but nobody has bought anything.
INSERT INTO Product (product_key) VALUES (1), (2);

-- expect-empty: no purchase rows, so no customers
