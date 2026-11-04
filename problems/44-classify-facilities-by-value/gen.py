"""Random data for Classify facilities by value.

generate(n_rows, seed) -> {table: rows}; n_rows is the number of bookings rows.
Rows are yielded lazily with O(1) memory, so n_rows=1_000_000 streams.

Generated for this repo with the exercise's schema; it is not the original clubdata dump.
- facilities: F = max(20, n_rows // 1000) (20 at 300 bookings, 1,000 at 1M), with unique names.
  ~10% (the highest facids) are never booked, so the "facilities with bookings" filter matters,
  and the booked count is never a multiple of 3, so NTILE's uneven sizes are always in play.
- ~35% of facilities are free for everyone (both costs 0). Their revenue is 0, so more than a third
  of the ranking is one big tie that straddles the average/low boundary: which tied facility
  lands in 'average' is decided by the facid tie-break (README "Assumptions") at every size.
- Of the rest, about a third are free for members only (guestcost 5-25); the others have
  membercost 0.50-20 and guestcost 2-5x that, in steps of 0.50.
- bookings: facility popularity is skewed (a few busy facilities, a long tail); 20% of bookings
  are by GUEST (memid 0); slots 1-6, skewed toward short bookings; starttime spread over 2024.
"""
import datetime as dt
import random

KINDS = ["Court", "Lane", "Studio", "Room", "Pitch", "Table", "Range", "Pool", "Wall", "Simulator"]
PREFIX = ["North", "South", "East", "West", "Upper", "Lower", "Main", "Garden", "Roof", "Annex"]
START = dt.datetime(2024, 1, 1, 7, 0, 0)


def _n_facilities(n_rows: int) -> int:
    return max(20, n_rows // 1000)


def _booked_cutoff(n_fac: int) -> int:
    cut = int(n_fac * 0.9)            # facids above this are never booked
    return cut - 1 if cut % 3 == 0 else cut


def _facilities(n_fac: int, seed: int):
    rng = random.Random(f"{seed}-facilities")
    for facid in range(1, n_fac + 1):
        name = f"{PREFIX[facid % len(PREFIX)]} {KINDS[(facid // len(PREFIX)) % len(KINDS)]} {facid}"
        r = rng.random()
        if r < 0.35:
            member, guest = 0.0, 0.0
        elif r < 0.55:
            member, guest = 0.0, rng.randint(10, 50) / 2
        else:
            member = rng.randint(1, 40) / 2
            guest = round(member * rng.choice([2, 2.5, 3, 4, 5]) * 2) / 2
        yield (facid, name, member, guest, rng.randint(50, 20000) * 10, rng.randint(5, 400) * 5)


def _bookings(n_rows: int, n_fac: int, seed: int):
    rng = random.Random(f"{seed}-bookings")
    booked = _booked_cutoff(n_fac)
    n_members = max(10, n_rows // 50)
    for bookid in range(1, n_rows + 1):
        facid = 1 + int(booked * rng.random() ** 2)      # skew toward low facids
        memid = 0 if rng.random() < 0.2 else rng.randint(1, n_members)
        slots = 1 + int(6 * rng.random() ** 1.5)
        start = START + dt.timedelta(minutes=30 * rng.randrange(366 * 48))
        yield (bookid, facid, memid, start, slots)


def generate(n_rows: int, seed: int) -> dict:
    n_fac = _n_facilities(n_rows)
    return {
        "facilities": _facilities(n_fac, seed),
        "bookings": _bookings(max(1, n_rows), n_fac, seed),
    }
