"""Random data for Median Order Amount per Store.

generate(n_rows, seed) -> {table: rows}; n_rows is the number of StoreOrders rows.
Rows are yielded lazily with O(1) memory, so n_rows=1_000_000 streams.

Distributions chosen to exercise the median logic:
- Two kinds of store. 90% of orders go to S = max(5, n_rows // 100) "chain" stores (10,000 at 1M
  rows) with a heavy skew (store = 1 + floor(S * r^2)): the biggest store gets ~1% of all orders.
  10% go to M = n_rows // 15 small shops, uniformly (about 1.5 orders each), so stores with 1, 2
  and 3 orders occur in every dataset alongside stores with thousands; odd and even counts are
  both common.
- Amounts: half are catalogue prices (x.99 / x.49 / x.00 from a short list), so duplicate amounts
  inside one store are common and often sit at the middle positions; the rest are a long-tailed
  amount rounded to the cent. Even-sized stores regularly produce a midpoint with a third decimal
  of 5, which exercises ROUND.
- order_id is assigned in time order and is unrelated to amount, so the (amount, order_id)
  tie-break order differs from insertion order.
"""
import random

PRICES = [4.99, 9.99, 9.99, 14.49, 19.99, 19.99, 24.00, 29.99, 49.99, 99.00]


def _orders(n_rows: int, seed: int):
    rng = random.Random(f"{seed}-orders")
    n_stores = max(5, n_rows // 100)
    n_small = max(2, n_rows // 15)
    for order_id in range(1, n_rows + 1):
        if rng.random() < 0.1:
            store = n_stores + 1 + rng.randrange(n_small)
        else:
            store = 1 + int(n_stores * rng.random() ** 2)
        if rng.random() < 0.5:
            amount = rng.choice(PRICES)
        else:
            amount = round(min(99_999.0, rng.lognormvariate(3.2, 0.9)), 2)
        yield (order_id, store, f"{amount:.2f}")


def generate(n_rows: int, seed: int) -> dict:
    return {"StoreOrders": _orders(max(1, n_rows), seed)}
