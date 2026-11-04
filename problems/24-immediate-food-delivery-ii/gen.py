"""Random data for Immediate Food Delivery II.

generate(n_rows, seed) -> {table: rows}; n_rows is the number of Delivery rows.
Rows are yielded lazily, one customer at a time (the last customer is truncated to hit n_rows exactly).

Distributions chosen to exercise the logic:
- Each customer has 1-8 orders (a single order about a third of the time). The first order date is unique
  per customer (the spec's guarantee); later orders fall 1-300 days after it and MAY share a date.
- ~45% of orders are immediate (preferred date = order date); the rest are 1-7 days later. Immediate-ness
  is independent of whether the order is the first one, so "first order only" differs from "all orders".
- delivery_id is sequential over the shuffled rows of a customer, so the smallest id is usually not the
  earliest order, and ids carry no date order.
- Order dates start in 2018-2019, with ~8% of first orders on a month end.
"""
import datetime as dt
import random

BASE = dt.date(2018, 1, 1)
MONTH_ENDS = [dt.date(2018, 1, 31), dt.date(2018, 2, 28), dt.date(2018, 4, 30), dt.date(2018, 12, 31),
              dt.date(2019, 5, 31), dt.date(2019, 8, 31), dt.date(2019, 11, 30)]


def _deliveries(n_rows: int, seed: int):
    rng = random.Random(f"{seed}-delivery")
    left, cust, did = n_rows, 0, 0
    while left > 0:
        cust += 1
        first = rng.choice(MONTH_ENDS) if rng.random() < 0.08 else BASE + dt.timedelta(days=rng.randrange(730))
        k = min(rng.choices(range(1, 9), [33, 20, 14, 10, 8, 6, 5, 4])[0], left)
        left -= k
        dates = [first] + [first + dt.timedelta(days=rng.randint(1, 300)) for _ in range(k - 1)]
        rows = []
        for d in dates:
            pref = d if rng.random() < 0.45 else d + dt.timedelta(days=rng.randint(1, 7))
            rows.append((cust, d, pref))
        rng.shuffle(rows)
        for c, d, pref in rows:
            did += 1
            yield (did, c, d, pref)


def generate(n_rows: int, seed: int) -> dict:
    return {"Delivery": _deliveries(n_rows, seed)}
