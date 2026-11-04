"""Random data for Find Stores with Inventory Imbalance.

generate(n_rows, seed) -> {table: rows}; n_rows is the number of `inventory` rows. Rows are yielded
lazily; only the list of per-store sizes (about n_rows / 6 small ints) is held in memory.

Distributions chosen to exercise the logic:
- Store sizes are drawn from 1..12 with weights, so ~35% of stores have fewer than 3 products
  (excluded by the "at least 3" rule) and ~10% have exactly 3 (the boundary). The last store is
  truncated so the inventory has exactly n_rows rows.
- Prices come from a short list (7 values), so ties for the highest and for the lowest price are
  common, and some stores have a single price for every product (the same row is both ends).
- Quantities are 1..30, so ties on (price, quantity) also happen and the product_name tie-break is exercised.
- Roughly half of all stores satisfy "expensive quantity < cheapest quantity".
- product_name is unique within a store (the schema enforces it) but is drawn from a shared pool,
  so the same name appears in many stores.
"""
import random

PRICES = ["1.00", "2.50", "5.00", "10.00", "20.00", "50.00", "100.00"]
SIZE_CHOICES = list(range(1, 13))
SIZE_WEIGHTS = [8, 12, 12, 14, 12, 10, 8, 7, 6, 5, 3, 3]
NAME_POOL = [f"prod-{i:02d}" for i in range(1, 61)]


def _sizes(n_rows: int, seed: int):
    rng = random.Random(f"{seed}-sizes")
    left = n_rows
    while left > 0:
        k = min(rng.choices(SIZE_CHOICES, SIZE_WEIGHTS)[0], left)
        yield k
        left -= k


def _stores(n_rows: int, seed: int):
    for sid, _ in enumerate(_sizes(n_rows, seed), start=1):
        yield (sid, f"Store {sid}", f"City {sid % 97}")


def _inventory(n_rows: int, seed: int):
    rng = random.Random(f"{seed}-inventory")
    inv_id = 0
    for sid, size in enumerate(_sizes(n_rows, seed), start=1):
        names = rng.sample(NAME_POOL, size)
        flat_price = rng.choice(PRICES) if rng.random() < 0.05 else None  # a store with one price
        for name in names:
            inv_id += 1
            price = flat_price or rng.choice(PRICES)
            yield (inv_id, sid, name, rng.randint(1, 30), price)


def generate(n_rows: int, seed: int) -> dict:
    return {"stores": _stores(n_rows, seed), "inventory": _inventory(n_rows, seed)}
