"""Random data for Find Product Recommendation Pairs.

generate(n_rows, seed) -> {table: rows}; n_rows is the number of ProductPurchases rows.
Rows are yielded lazily so n_rows=1_000_000 streams without building lists.

Distributions chosen to exercise the logic:
- Products = max(80, n_rows // 40). Popularity is Zipf-like (weight 1 / rank^1.05): a few products are
  bought by many customers and co-occur often; a long tail of products has fewer than 3 customers, so
  the 'popular product' prune of approach 3 removes real rows.
- Basket sizes are skewed (1 + a lognormal-ish draw, capped at 30): most customers buy a few products, a few buy
  many, which is what makes the self-join's k*(k-1)/2 row explosion visible.
- ~3% of purchases have quantity 0 (quantity is irrelevant); others 1-5.
- ~1% of products have no ProductInfo row (the pair is still reported, with a NULL category).
- Categories: 8 names, so two products of a pair often share a category.
Customers are produced in id order until n_rows purchases exist (the last basket may be cut short).
"""
import bisect
import itertools
import random

CATEGORIES = ["Books", "Electronics", "Toys", "Garden", "Kitchen", "Sports", "Beauty", "Office"]


def _n_products(n_rows: int) -> int:
    return max(80, n_rows // 40)


def _info(n_products: int, seed: int):
    rng = random.Random(f"{seed}-info")
    for pid in range(1, n_products + 1):
        category = rng.choice(CATEGORIES)
        price = round(rng.uniform(1, 500), 2)
        if rng.random() < 0.01:
            continue                      # purchased product without a ProductInfo row
        yield (pid, category, price)


def _purchases(n_rows: int, n_products: int, seed: int):
    rng = random.Random(f"{seed}-purchases")
    cum = list(itertools.accumulate(1.0 / (r ** 1.05) for r in range(1, n_products + 1)))
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
            qty = 0 if rng.random() < 0.03 else rng.randint(1, 5)
            yield (uid, pid, qty)


def generate(n_rows: int, seed: int) -> dict:
    n_products = _n_products(n_rows)
    return {
        "ProductInfo": _info(n_products, seed),
        "ProductPurchases": _purchases(n_rows, n_products, seed),
    }
