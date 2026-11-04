"""Random data for Find Churn Risk Customers.

generate(n_rows, seed) -> {"subscription_events": rows}; n_rows is the number of events.
Rows are yielded lazily so n_rows=1_000_000 streams without building lists.

Distributions chosen to exercise the logic:
- Each user's history is a walk over plans (basic 10, standard 20, premium 30-40), starting with
  'start'; later events are upgrades, downgrades, cancels (followed ~50% of the time by a
  restart) and occasional same-plan price changes.
- ~12% of events land on the same day as the previous event (the event_id tiebreak decides the
  latest), and ~8% of users have two events on their last day.
- Gaps of 1-40 days, so the span hovers around the 60-day boundary; some amounts are exactly half
  of the user's maximum (15.00 vs 30.00, 20.00 vs 40.00).
- plan_name is NULL and monthly_amount 0 on cancel rows only. History length is skewed (1-30).
"""
import datetime as dt
import random

PRICES = {"basic": [10.00, 14.99, 15.00], "standard": [20.00, 25.00], "premium": [30.00, 40.00]}
ORDER = ["basic", "standard", "premium"]


def _events(n_rows: int, seed: int):
    rng = random.Random(f"{seed}-events")
    eid, user = 0, 0
    while eid < n_rows:
        user += 1
        d = dt.date(2023, 1, 1) + dt.timedelta(days=rng.randrange(600))
        plan = rng.choice(ORDER)
        n = rng.choice([1, 2, 2, 3, 3, 3, 4, 4, 5, 6, 8, 12, 30])
        active, last_type = True, None
        for i in range(n):
            if eid >= n_rows:
                return
            if i > 0 and rng.random() > 0.12:
                d += dt.timedelta(days=rng.choice([1, 5, 10, 15, 20, 29, 30, 31, 40]))
            if i == 0 or (not active):
                etype = "start"
                active = True
            else:
                x = rng.random()
                k = ORDER.index(plan)
                if x < 0.15:
                    etype = "cancel"
                elif x < 0.50 and k > 0:
                    etype, plan = "downgrade", ORDER[rng.randrange(k)]
                elif x < 0.85 and k < 2:
                    etype, plan = "upgrade", ORDER[rng.randrange(k + 1, 3)]
                else:
                    etype = rng.choice(["upgrade", "downgrade"])  # same plan, price change
            if etype == "cancel":
                active = False
                eid += 1
                yield (eid, user, d, "cancel", None, 0.00)
                if rng.random() < 0.5:
                    continue
                break
            eid += 1
            yield (eid, user, d, etype, plan, rng.choice(PRICES[plan]))
            last_type = etype
        if last_type and rng.random() < 0.08 and eid < n_rows:   # second event on the last day
            eid += 1
            etype2 = rng.choice(["upgrade", "downgrade", "cancel"])
            if etype2 == "cancel":
                yield (eid, user, d, "cancel", None, 0.00)
            else:
                p2 = rng.choice(ORDER)
                yield (eid, user, d, etype2, p2, rng.choice(PRICES[p2]))


def generate(n_rows: int, seed: int) -> dict:
    return {"subscription_events": _events(n_rows, seed)}
