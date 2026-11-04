"""Random data for Product Price at a Given Date (target date 2019-08-16).

generate(n_rows, seed) -> {table: rows}; n_rows is the number of price-change rows in Products.
Rows are yielded lazily, product by product, so n_rows=1_000_000 streams without building lists.

Distributions chosen to exercise the logic:
- Each product has 1-8 changes (the last product is truncated so there are exactly n_rows rows).
- Dates are distinct days within a product (the PK), spread over 2018-06-01 .. 2019-12-31 so the
  target date falls in the middle of most histories.
- ~15% of products have ALL their changes after the target date (the default price 10 applies);
  ~12% have a change exactly ON the target date; ~12% have changes on the days either side of it.
- Prices are random 1..100 and not monotonic, so "highest price" and "latest price" differ.
"""
import datetime as dt
import random

CUTOFF = dt.date(2019, 8, 16)
START = dt.date(2018, 6, 1)
END = dt.date(2019, 12, 31)
SPAN = (END - START).days + 1


def _histories(n_rows: int, seed: int):
    rng = random.Random(f"{seed}-products")
    left, pid = n_rows, 0
    after_start = (CUTOFF - START).days + 1  # offset of the first day after the cutoff
    while left > 0:
        pid += 1
        k = min(rng.choices(range(1, 9), [10, 15, 15, 15, 15, 12, 10, 8])[0], left)
        left -= k
        r = rng.random()
        if r < 0.15:                                       # every change is after the target date
            pool = range(after_start, SPAN)
            offsets = set(rng.sample(pool, min(k, len(pool))))
        else:
            offsets = set(rng.sample(range(SPAN), k))
            if r < 0.27:                                   # force a change exactly on the target date
                offsets.discard(max(offsets))
                offsets.add(after_start - 1)
            elif r < 0.39:                                 # force changes the day before / after
                offsets.discard(max(offsets))
                offsets.add(after_start - 2 if rng.random() < 0.5 else after_start)
        while len(offsets) < k:
            offsets.add(rng.randrange(SPAN))
        for off in sorted(offsets):
            yield (pid, rng.randint(1, 100), START + dt.timedelta(days=off))


def generate(n_rows: int, seed: int) -> dict:
    return {"Products": _histories(n_rows, seed)}
