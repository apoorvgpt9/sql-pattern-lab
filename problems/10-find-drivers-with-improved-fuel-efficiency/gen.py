"""Random data for Find Drivers with Improved Fuel Efficiency.

generate(n_rows, seed) -> {table: rows}; n_rows is the number of trips.
Rows are yielded lazily so n_rows=1_000_000 streams without building lists.

Distributions chosen to exercise the logic:
- Drivers = max(8, n_rows // 20). The top ~5% of driver ids never drive (no trips). Trips are skewed
  toward low driver ids, so a few drivers have many trips and a tail has very few (often one half only).
- Each driver has a base efficiency (5-15 km/L) and a second-half shift in [-1.5, +1.5], so roughly half
  of the drivers improve and half decline. A trip's efficiency is the base +/- noise.
- trip_date spans 2021-2023; ~4% fall exactly on Jan 1 / Jun 30 / Jul 1 / Dec 31 (half boundaries); ~1% NULL.
- ~2% of trips have fuel_consumed 0, ~1% NULL fuel, ~1% NULL distance (efficiency undefined).
- ~2% of trips belong to a driver_id that is not in drivers.
- distance and fuel are DECIMAL(10,2), so ratios are not exact (repeating decimals) and the rounding
  order matters.
"""
import datetime as dt
import random

START, DAYS = dt.date(2021, 1, 1), 3 * 365
EDGE_MD = [(1, 1), (6, 30), (7, 1), (12, 31)]


def _sizes(n_rows: int):
    return max(8, n_rows // 20)


def _drivers(n_drivers: int, seed: int):
    for did in range(1, n_drivers + 1):
        yield (did, f"Driver {did:07d}")


def _trips(n_rows: int, n_drivers: int, seed: int):
    rng = random.Random(f"{seed}-trips")
    prof = random.Random(f"{seed}-profiles")
    base = [prof.uniform(5, 15) for _ in range(n_drivers + 1)]
    shift = [prof.uniform(-1.5, 1.5) for _ in range(n_drivers + 1)]
    active = max(1, int(n_drivers * 0.95))
    for tid in range(1, n_rows + 1):
        if rng.random() < 0.02:
            driver = n_drivers + rng.randint(1, 50)           # not a driver
            b, sh = 8.0, 1.0
        else:
            driver = int(active * rng.random() ** 1.6) + 1    # skew to low ids
            b, sh = base[driver], shift[driver]
        r = rng.random()
        if r < 0.01:
            trip_date = None
        elif r < 0.05:
            month, day = rng.choice(EDGE_MD)
            trip_date = dt.date(2021 + rng.randrange(3), month, day)
        else:
            trip_date = START + dt.timedelta(days=rng.randrange(DAYS))
        second = trip_date is not None and trip_date.month >= 7
        eff = max(1.0, rng.gauss(b + (sh if second else 0.0), 1.2))
        fuel = round(rng.uniform(5, 60), 2)
        dist = round(eff * fuel, 2)
        r = rng.random()
        if r < 0.02:
            fuel = 0
        elif r < 0.03:
            fuel = None
        elif r < 0.04:
            dist = None
        yield (tid, driver, trip_date, dist, fuel)


def generate(n_rows: int, seed: int) -> dict:
    n_drivers = _sizes(n_rows)
    return {"drivers": _drivers(n_drivers, seed), "trips": _trips(n_rows, n_drivers, seed)}
