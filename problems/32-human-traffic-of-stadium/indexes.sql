-- Index recommended in README "At scale" (b). The bench runs every solution without it, then with it.
-- The original table has no key on id. Making id the primary key clusters the rows in id order:
--   01: each s2/s3 probe (id = s1.id + k) becomes a primary-key lookup instead of a scan or hash;
--   02, 03: the window's ORDER BY id matches the clustered order of the scan.
ALTER TABLE Stadium ADD PRIMARY KEY (id);
