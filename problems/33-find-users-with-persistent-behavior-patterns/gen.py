"""Random data for Find Users with Persistent Behavior Patterns.

generate(n_rows, seed) -> {"activity": rows}; n_rows is the number of activity rows.
Rows are yielded lazily so n_rows=1_000_000 streams without building lists.

Distributions chosen to exercise the logic:
- Users are active over 20-120 day windows that often start in late December or late February,
  so streaks cross year ends and the end of February (leap and non-leap years).
- Actions are sticky: the next active day repeats the previous action with probability 0.85, so
  streaks of 1-15 days are common and the 4/5-day boundary is hit often.
- ~10% of days are skipped (gap) and ~7% are multi-action days (2-3 distinct actions), which must
  both be removed and split the streak.
- Some users have several streaks of equal maximum length (the tie rule in README "Assumptions").
- Heavy users (~5%) are active 3x longer, so per-user partitions are skewed.
"""
import datetime as dt
import random

ACTIONS = ["login", "view", "click", "post", "like", "share", "search", "zoom"]
STARTS = [(12, 20), (2, 20), (6, 1), (9, 15)]  # (month, day): near year end / end of February


def _activity(n_rows: int, seed: int):
    rng = random.Random(f"{seed}-activity")
    emitted, user = 0, 0
    while emitted < n_rows:
        user += 1
        month, day = rng.choice(STARTS)
        d = dt.date(rng.choice([2019, 2022, 2023, 2024]), month, day) + dt.timedelta(days=rng.randrange(10))
        span = rng.randint(20, 120) * (3 if rng.random() < 0.05 else 1)
        action = rng.choice(ACTIONS)
        for _ in range(span):
            if emitted >= n_rows:
                return
            d += dt.timedelta(days=1)
            r = rng.random()
            if r < 0.10:
                continue  # no activity: a gap
            if rng.random() > 0.85:
                action = rng.choice(ACTIONS)
            if r < 0.17:  # multi-action day: this day must be removed
                extra = rng.sample([a for a in ACTIONS if a != action], rng.choice([1, 1, 2]))
                for a in [action] + extra:
                    if emitted >= n_rows:
                        return
                    yield (user, d, a)
                    emitted += 1
            else:
                yield (user, d, action)
                emitted += 1


def generate(n_rows: int, seed: int) -> dict:
    return {"activity": _activity(n_rows, seed)}
