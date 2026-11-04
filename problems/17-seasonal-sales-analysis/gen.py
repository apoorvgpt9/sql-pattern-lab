"""Random data for Seasonal Sales Analysis.

generate(n_rows, seed) -> {table: rows}; n_rows is the number of base `sales` rows. Up to 8 extra
"tie-forcing" sales are appended after them (see below). Rows are yielded lazily, so n_rows=1_000_000
streams without building lists.

Distributions chosen to exercise the logic:
- products = n_rows // 100 (at least 8), spread over 12 categories with a skewed popularity, so
  category totals are close but not equal.
- sale_date spans 2021-2023; ~10% fall on a season boundary day (Feb 28, leap day Feb 29, Mar 1, May 31, Jun 1,
  Aug 31, Sep 1, Nov 30, Dec 1, Dec 31, Jan 1), which are the days a wrong month mapping gets wrong.
- quantity 1..20, price from a small price list (2-decimal DECIMAL values, so totals are exact).
- ~2% of sales reference a product_id that is not in products.
- Ties: random data almost never ties on BOTH quantity and revenue, so for each season the generator
  may append two sales of huge quantity for categories 'Tie_A'/'Tie_Z' (which are dominated by no
  normal category). Depending on seed and season they tie fully (alphabetical decides: Tie_A), tie
  on quantity only (revenue decides: Tie_Z), or are absent (normal data decides).
"""
import datetime as dt
import random

CATEGORIES = ["Apparel", "Books", "Toys", "Garden", "Games", "Outdoor", "Kitchen", "Beauty",
              "Footwear", "Electronics", "Pets", "Office"]
PRICES = ["1.00", "2.50", "3.99", "5.00", "9.95", "12.00", "20.00", "49.99"]
BOUNDARY_DAYS = [dt.date(2022, 2, 28), dt.date(2024, 2, 29), dt.date(2022, 3, 1),
                 dt.date(2022, 5, 31), dt.date(2022, 6, 1), dt.date(2022, 8, 31), dt.date(2022, 9, 1),
                 dt.date(2022, 11, 30), dt.date(2022, 12, 1), dt.date(2022, 12, 31), dt.date(2023, 1, 1)]
START, DAYS = dt.date(2021, 1, 1), 3 * 365
# One representative day per season for the tie-forcing sales.
SEASON_DAYS = {"Winter": dt.date(2022, 1, 15), "Spring": dt.date(2022, 4, 15),
               "Summer": dt.date(2022, 7, 15), "Fall": dt.date(2022, 10, 15)}


def _n_products(n_rows: int) -> int:
    return max(8, n_rows // 100)


def _products(n_products: int, seed: int):
    rng = random.Random(f"{seed}-products")
    weights = [1 + 3 * (i % 4 == 0) for i in range(len(CATEGORIES))]
    for pid in range(1, n_products + 1):
        yield (pid, f"product-{pid}", rng.choices(CATEGORIES, weights)[0])
    yield (n_products + 1, "tie-a", "Tie_A")
    yield (n_products + 2, "tie-z", "Tie_Z")


def _sales(n_rows: int, n_products: int, seed: int):
    rng = random.Random(f"{seed}-sales")
    for sid in range(1, n_rows + 1):
        r = rng.random()
        if r < 0.02:
            pid = n_products + 1000 + rng.randint(1, 50)   # not in products
        else:
            pid = int(n_products * rng.random() ** 1.5) + 1  # a few popular products
        d = rng.random()
        if d < 0.10:
            day = rng.choice(BOUNDARY_DAYS)
        else:
            day = START + dt.timedelta(days=rng.randrange(DAYS))
        yield (sid, pid, day, rng.randint(1, 20), rng.choice(PRICES))
    # Tie-forcing sales, after the base rows so their ids never collide.
    tie_a, tie_z = n_products + 1, n_products + 2
    big = 20 * n_rows + 1000  # larger than any ordinary category total (quantity <= 20 per row)
    sid = n_rows
    for i, season in enumerate(["Winter", "Spring", "Summer", "Fall"]):
        mode = (seed + i) % 3
        day = SEASON_DAYS[season]
        if mode == 0:        # full tie: same quantity and revenue -> alphabetical (Tie_A)
            sid += 1; yield (sid, tie_z, day, big, "1.00")
            sid += 1; yield (sid, tie_a, day, big, "1.00")
        elif mode == 1:      # quantity tie, revenue differs -> revenue decides (Tie_Z)
            sid += 1; yield (sid, tie_a, day, big, "2.00")
            sid += 1; yield (sid, tie_z, day, big, "3.00")
        # mode 2: no tie-forcing sale; the season is decided by the normal data


def generate(n_rows: int, seed: int) -> dict:
    n_products = _n_products(n_rows)
    return {
        "products": _products(n_products, seed),
        "sales": _sales(n_rows, n_products, seed),
    }
