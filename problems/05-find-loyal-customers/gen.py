"""Random data for Find Loyal Customers.

generate(n_rows, seed) -> {table: rows}; n_rows is the number of customer_transactions rows (one table).
Rows are yielded lazily, customer by customer, so n_rows=1_000_000 streams without building lists.

Distributions chosen to exercise the logic, not to look pretty:
- Customers have 1..~40 transactions (mean about 6), so many have fewer than 3 purchases.
- Each customer has a fixed refund probability from {0, 0, 0.05, 0.1, 0.2, 0.2, 0.3}; with ~5 transactions the
  exact 1-in-5 = 20% boundary shows up regularly.
- Each customer's first and second transaction are placed exactly `span` days apart with span drawn from
  {0, 3, 15, 29, 30, 30, 31, 45, 90, 200}, and the rest fall in between, so spans of exactly 29/30/31 days
  occur constantly. Dates are in 2023-2024 (2024 is a leap year).
- Refunds can be the earliest or latest transaction, so the span over all types differs from the span over purchases.
"""
import datetime as dt
import random

START = dt.date(2023, 1, 1)
SPANS = [0, 3, 15, 29, 30, 30, 31, 45, 90, 200]
REFUND_P = [0.0, 0.0, 0.05, 0.1, 0.2, 0.2, 0.3]


def generate(n_rows: int, seed: int) -> dict:
    return {"customer_transactions": _transactions(n_rows, seed)}


def _transactions(n_rows: int, seed: int):
    rng = random.Random(f"{seed}-transactions")
    tid = 0
    cid = 0
    while tid < n_rows:
        cid += 1
        k = min(1 + int(rng.expovariate(1 / 5)), 40, n_rows - tid)
        refund_p = rng.choice(REFUND_P)
        start = START + dt.timedelta(days=rng.randrange(400))
        span = rng.choice(SPANS)
        for j in range(k):
            if j == 0:
                day = start
            elif j == 1:
                day = start + dt.timedelta(days=span)
            else:
                day = start + dt.timedelta(days=rng.randint(0, span))
            ttype = "refund" if rng.random() < refund_p else "purchase"
            tid += 1
            yield (tid, cid, day, round(rng.uniform(1, 500), 2), ttype)
