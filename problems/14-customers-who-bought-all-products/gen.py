"""Random data for Customers Who Bought All Products.

generate(n_rows, seed) -> {table: rows}; n_rows is the number of Customer rows.
Rows are yielded lazily so n_rows=1_000_000 streams without building lists.

Distributions chosen to exercise the logic:
- Product keys are 10, 20, ..., 10*P (not 1..P), P = clamp(n_rows // 25, 5, 12): few products, so "bought all of them" is possible.
  P >= 5 and the table is never empty (the spec does not test an empty Product table; approaches differ there).
- Customers are produced in id order until n_rows rows exist. Every 12th customer is a completionist (all P products),
  every 7th customer misses exactly one product (so many near-misses), the rest buy a random subset, with heavy
  skew toward small subsets.
- Each product a customer buys is repeated with probability ~25% (duplicate rows are allowed, and equal row counts
  with fewer distinct products must occur).
- ~1% of rows have product_key NULL.
- customer_id has gaps (id = 3 * k + 1), so ids are not 1..n.
"""
import random


def _n_products(n_rows: int) -> int:
    return max(5, min(12, n_rows // 25))


def _products(n_products: int, seed: int):
    for i in range(1, n_products + 1):
        yield (10 * i,)


def _customers(n_rows: int, n_products: int, seed: int):
    rng = random.Random(f"{seed}-customers")
    keys = [10 * i for i in range(1, n_products + 1)]
    emitted, k = 0, 0
    while emitted < n_rows:
        k += 1
        cid = 3 * k + 1
        if k % 12 == 0:
            basket = list(keys)
        elif k % 7 == 0:
            missing = rng.choice(keys)
            basket = [x for x in keys if x != missing]
        else:
            size = min(n_products - 1, 1 + int(rng.expovariate(1 / 2.5)))
            basket = rng.sample(keys, size)
        rows = []
        for p in basket:
            rows.append((cid, p))
            while rng.random() < 0.25:
                rows.append((cid, p))
        if rng.random() < 0.04:
            rows.append((cid, None))
        rng.shuffle(rows)
        for row in rows:
            if emitted >= n_rows:
                return
            emitted += 1
            yield row


def generate(n_rows: int, seed: int) -> dict:
    n_products = _n_products(n_rows)
    return {"Product": _products(n_products, seed), "Customer": _customers(n_rows, n_products, seed)}
