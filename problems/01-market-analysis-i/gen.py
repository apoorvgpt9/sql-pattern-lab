"""Random data for Market Analysis I.

generate(n_rows, seed) -> {table: rows}; n_rows is the number of Orders rows.
Rows are yielded lazily so n_rows=1_000_000 streams without building lists.

Distributions chosen to exercise the logic, not to look pretty:
- Users = n_rows // 5. The top 10% of user_ids never buy, so zero counts are common.
- Buyers are skewed toward low ids (a few heavy buyers, a long tail).
- order_date spans 2018-2020; ~4% fall exactly on 2018-12-31 / 2019-01-01 / 2019-12-31 / 2020-01-01;
  ~1% are NULL.
- ~3% of orders have buyer_id NULL (enough that every seed has some in 2019) and ~2% a buyer_id that is not in Users.
- seller_id is any user, sometimes the buyer.
- ~2% NULL join_date, ~5% NULL favorite_brand.
"""
import datetime as dt
import random

BRANDS = ["Acme", "Globex", "Initech", "Umbrella", "Hooli", "Stark", "Wayne", "Tyrell"]
BOUNDARY_DAYS = [dt.date(2018, 12, 31), dt.date(2019, 1, 1), dt.date(2019, 12, 31), dt.date(2020, 1, 1)]
ORDER_START, ORDER_DAYS = dt.date(2018, 1, 1), 3 * 365
JOIN_START, JOIN_DAYS = dt.date(2017, 1, 1), 3 * 365


def _sizes(n_rows: int):
    n_users = max(3, n_rows // 5)
    n_items = max(1, min(1000, n_rows // 50))
    return n_users, n_items


def _users(n_users: int, seed: int):
    rng = random.Random(f"{seed}-users")
    for uid in range(1, n_users + 1):
        join = None if rng.random() < 0.02 else JOIN_START + dt.timedelta(days=rng.randrange(JOIN_DAYS))
        brand = None if rng.random() < 0.05 else rng.choice(BRANDS)
        yield (uid, join, brand)


def _items(n_items: int, seed: int):
    rng = random.Random(f"{seed}-items")
    for iid in range(1, n_items + 1):
        yield (iid, rng.choice(BRANDS))


def _orders(n_rows: int, n_users: int, n_items: int, seed: int):
    rng = random.Random(f"{seed}-orders")
    buyers_pool = max(1, int(n_users * 0.9))  # ids above this never buy
    for oid in range(1, n_rows + 1):
        r = rng.random()
        if r < 0.03:
            buyer = None
        elif r < 0.05:
            buyer = n_users + rng.randint(1, 1000)  # not a user
        else:
            buyer = int(buyers_pool * rng.random() ** 2) + 1  # skew toward low ids
        d = rng.random()
        if d < 0.01:
            order_date = None
        elif d < 0.05:
            order_date = rng.choice(BOUNDARY_DAYS)
        else:
            order_date = ORDER_START + dt.timedelta(days=rng.randrange(ORDER_DAYS))
        seller = buyer if (buyer and rng.random() < 0.02) else rng.randint(1, n_users)
        yield (oid, order_date, rng.randint(1, n_items), buyer, seller)


def generate(n_rows: int, seed: int) -> dict:
    n_users, n_items = _sizes(n_rows)
    return {
        "Users": _users(n_users, seed),
        "Items": _items(n_items, seed),
        "Orders": _orders(n_rows, n_users, n_items, seed),
    }
