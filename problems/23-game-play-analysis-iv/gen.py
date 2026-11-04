"""Random data for Game Play Analysis IV.

generate(n_rows, seed) -> {table: rows}; n_rows is the number of Activity rows.
Rows are yielded lazily, one player at a time (the last player is truncated to hit n_rows exactly).

Distributions chosen to exercise the logic:
- Each player has 1-12 active days (single-day players are common), starting on a random day in
  2016-2018; ~10% start on a month end / year end / Feb 28, so "the day after" crosses a month, year
  or (in 2016) leap-day boundary.
- ~35% of players are active on the day right after their first login. Others have a gap, and ~30% of
  those have a run of consecutive days LATER (these are the "any consecutive pair" trap).
- device_id varies per row (1..5), so the first-login device is often not the second-day device.
- games_played 0..20. Rows of a player are shuffled, so insertion order is not chronological.
"""
import datetime as dt
import random

BASE = dt.date(2016, 1, 1)
SPECIAL_FIRSTS = [dt.date(2016, 1, 31), dt.date(2016, 2, 28), dt.date(2016, 2, 29), dt.date(2017, 2, 28),
                  dt.date(2016, 12, 31), dt.date(2017, 12, 31), dt.date(2018, 4, 30)]


def _players(n_rows: int, seed: int):
    rng = random.Random(f"{seed}-activity")
    left, pid = n_rows, 0
    while left > 0:
        pid += 1
        first = rng.choice(SPECIAL_FIRSTS) if rng.random() < 0.10 else BASE + dt.timedelta(days=rng.randrange(3 * 365))
        k = min(rng.choices(range(1, 13), [30, 14, 10, 8, 7, 6, 5, 5, 4, 4, 4, 3])[0], left)
        left -= k
        offsets = {0}
        if k > 1 and rng.random() < 0.35:
            offsets.add(1)
        elif k > 2 and rng.random() < 0.30:                # gap after the first day, then a run of days
            start = rng.randint(2, 40)
            offsets.update({start, start + 1})
        while len(offsets) < k:
            offsets.add(rng.randint(2, 120))
        rows = [(pid, rng.randint(1, 5), first + dt.timedelta(days=o), rng.randint(0, 20))
                for o in sorted(offsets)[:k]]
        rng.shuffle(rows)
        yield from rows


def generate(n_rows: int, seed: int) -> dict:
    return {"Activity": _players(n_rows, seed)}
