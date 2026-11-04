"""Random data for Find Category Recommendation Pairs.

generate(n_rows, seed) -> {table: rows}; n_rows is the number of ProductPurchases rows.
Rows are yielded lazily so n_rows=1_000_000 streams without building lists.

Distributions chosen to exercise the logic:
- Products = max(80, n_rows // 40); categories = 12 + a few extra for big inputs, with a skewed (Zipf-like) share of
  products per category, so some categories are large (a customer often buys SEVERAL products from the same
  category, which is what makes the product-level fan-out and the dedupe matter) and a few are tiny.
- Product popularity is Zipf-like, basket sizes are skewed (1 + lognormal, capped at 30).
- ~3% of purchases have quantity 0 (irrelevant).
- ~1% of products have no ProductInfo row; ~1% of ProductInfo rows have category NULL.
- Category names are mixed-length words in a fixed list, so alphabetical order differs from category creation order.
Customers are produced in id order until n_rows purchases exist (the last basket may be cut short).
"""
import bisect
import itertools
import random

CATEGORIES = ["Books", "Electronics", "Toys", "Garden", "Kitchen", "Sports", "Beauty", "Office", "Pets",
              "Music", "Tools", "Games", "Health", "Travel", "Auto", "Baby", "Art", "Food", "Shoes", "Jewelry"]


def _n_products(n_rows: int) -> int:
    return max(80, n_rows // 40)


def _n_categories(n_rows: int) -> int:
    return min(len(CATEGORIES), 8 + n_rows // 20000)


def _info(n_products: int, n_cats: int, seed: int):
    rng = random.Random(f"{seed}-info")
    weights = list(itertools.accumulate(1.0 / (r ** 0.9) for r in range(1, n_cats + 1)))
    for pid in range(1, n_products + 1):
        cat = CATEGORIES[bisect.bisect_left(weights, rng.random() * weights[-1])]
        r = rng.random()
        if r < 0.01:
            continue                                  # purchased product with no ProductInfo row
        yield (pid, None if r < 0.02 else cat, round(rng.uniform(1, 500), 2))


def _purchases(n_rows: int, n_products: int, seed: int):
    rng = random.Random(f"{seed}-purchases")
    cum = list(itertools.accumulate(1.0 / (r ** 1.0) for r in range(1, n_products + 1)))
    total = cum[-1]
    emitted, uid = 0, 0
    while emitted < n_rows:
        uid += 1
        size = min(30, 1 + int(rng.lognormvariate(1.0, 0.9)))
        basket = set()
        attempts = 0
        while len(basket) < min(size, n_products) and attempts < size * 20:
            attempts += 1
            basket.add(bisect.bisect_left(cum, rng.random() * total) + 1)
        for pid in sorted(basket):
            if emitted >= n_rows:
                return
            emitted += 1
            yield (uid, pid, 0 if rng.random() < 0.03 else rng.randint(1, 5))


def generate(n_rows: int, seed: int) -> dict:
    n_products = _n_products(n_rows)
    return {
        "ProductInfo": _info(n_products, _n_categories(n_rows), seed),
        "ProductPurchases": _purchases(n_rows, n_products, seed),
    }
