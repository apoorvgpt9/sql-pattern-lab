"""Random data for Analyze Subscription Conversion.

generate(n_rows, seed) -> {table: rows}; n_rows is the number of UserActivity rows (users are produced in
order until that many rows exist; the last user may be cut short).
Rows are yielded lazily so n_rows=1_000_000 streams without building lists.

Distributions chosen to exercise the logic. Each user gets one archetype:
- 35% trial + paid (converted), of which ~5% have their paid rows BEFORE the trial (dates are not compared),
- 10% trial + paid + cancelled,
- 25% trial only, 12% paid only, 8% trial + cancelled, 5% paid + cancelled, 5% cancelled only.
Trial lasts 1-14 days, paid 1-40 days. Durations are skewed (many small values, 3% exactly 0, a few very large),
so averages are repeating decimals and ties/rounding are common. Cancelled rows have deliberately huge durations
so that leaking them into an average is obvious.
"""
import datetime as dt
import random

START = dt.date(2023, 1, 1)


def _duration(rng: random.Random) -> int:
    r = rng.random()
    if r < 0.03:
        return 0
    if r < 0.93:
        return int(rng.expovariate(1 / 25)) + 1
    return rng.randint(120, 600)


def _rows(n_rows: int, seed: int):
    rng = random.Random(f"{seed}-activity")
    emitted, uid = 0, 0
    while emitted < n_rows:
        uid += 1
        r = rng.random()
        if r < 0.35:
            kinds = ("trial", "paid")
        elif r < 0.45:
            kinds = ("trial", "paid", "cancelled")
        elif r < 0.70:
            kinds = ("trial",)
        elif r < 0.82:
            kinds = ("paid",)
        elif r < 0.90:
            kinds = ("trial", "cancelled")
        elif r < 0.95:
            kinds = ("paid", "cancelled")
        else:
            kinds = ("cancelled",)
        base = START + dt.timedelta(days=rng.randrange(600))
        n_trial = rng.randint(1, 14) if "trial" in kinds else 0
        n_paid = rng.randint(1, 40) if "paid" in kinds else 0
        paid_first = "trial" in kinds and "paid" in kinds and rng.random() < 0.05
        user_rows = []
        if paid_first:
            for i in range(n_paid):
                user_rows.append((uid, base + dt.timedelta(days=i), "paid", _duration(rng)))
            for i in range(n_trial):
                user_rows.append((uid, base + dt.timedelta(days=n_paid + i), "free_trial", _duration(rng)))
        else:
            for i in range(n_trial):
                user_rows.append((uid, base + dt.timedelta(days=i), "free_trial", _duration(rng)))
            for i in range(n_paid):
                user_rows.append((uid, base + dt.timedelta(days=n_trial + i), "paid", _duration(rng)))
        if "cancelled" in kinds:
            user_rows.append((uid, base + dt.timedelta(days=n_trial + n_paid + 1), "cancelled", rng.randint(500, 2000)))
        for row in user_rows:
            if emitted >= n_rows:
                return
            emitted += 1
            yield row


def generate(n_rows: int, seed: int) -> dict:
    return {"UserActivity": _rows(n_rows, seed)}
