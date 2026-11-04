"""Random data for Find Zombie Sessions.

generate(n_rows, seed) -> {"app_events": rows}; n_rows is the number of events.
Rows are yielded lazily so n_rows=1_000_000 streams without building lists.

Distributions chosen to exercise the logic:
- Sessions of 2-30 events (skewed), each owned by one user; users have several sessions.
- Session length in time is drawn around the 30-minute boundary (some end at exactly 30:00, some at
  30:xx seconds), and ~10% of sessions cross midnight.
- Scroll counts cluster around 4-6; click counts are tuned so clicks/scrolls lands on 0.20 exactly
  (e.g. 1/5, 2/10) fairly often; ~25% of sessions contain a purchase (sometimes with value 0 or NULL).
- Sessions often open with app_open and close with app_close, which count toward duration.
- event_value is pixels for scrolls, an amount for purchases, NULL otherwise (~5% NULL anyway).
"""
import datetime as dt
import random

START = dt.datetime(2024, 1, 1)


def _events(n_rows: int, seed: int):
    rng = random.Random(f"{seed}-events")
    eid, sess = 0, 0
    n_users = max(2, n_rows // 40)
    while eid < n_rows:
        sess += 1
        user = rng.randint(1, n_users)
        sid = f"s{sess:07d}"
        scrolls = rng.choice([0, 2, 3, 4, 5, 5, 5, 6, 6, 8, 10, 15])
        clicks = rng.choice([0, 0, 1, 1, 2, max(1, scrolls // 5), scrolls // 5 + 1])
        purchases = 1 if rng.random() < 0.25 else 0
        kinds = ["scroll"] * scrolls + ["click"] * clicks + ["purchase"] * purchases
        rng.shuffle(kinds)
        if rng.random() < 0.7:
            kinds = ["app_open"] + kinds + ["app_close"]
        if not kinds:
            kinds = ["app_open"]
        span_s = rng.choice([29 * 60, 30 * 60, 30 * 60 + rng.randint(1, 59), 31 * 60,
                             rng.randint(5, 90) * 60, rng.randint(5, 90) * 60])
        t0 = START + dt.timedelta(days=rng.randrange(200), seconds=rng.randrange(86400))
        if rng.random() < 0.1:
            t0 = t0.replace(hour=23, minute=40)
        n = len(kinds)
        offsets = sorted([0, span_s] + [rng.randint(0, span_s) for _ in range(max(0, n - 2))])[:n]
        for kind, off in zip(kinds, offsets):
            if eid >= n_rows:
                return
            eid += 1
            if kind == "scroll":
                value = None if rng.random() < 0.05 else rng.randint(50, 2000)
            elif kind == "purchase":
                value = rng.choice([None, 0, 5, 20, 99])
            else:
                value = None
            yield (eid, user, t0 + dt.timedelta(seconds=off), kind, sid, value)


def generate(n_rows: int, seed: int) -> dict:
    return {"app_events": _events(n_rows, seed)}
