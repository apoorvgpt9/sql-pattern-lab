"""Random data for Produce a CTE that can return the upward recommendation chain for any member.

generate(n_rows, seed) -> {table: rows}; n_rows is the number of members (plus the GUEST row, memid 0).
Rows are yielded lazily with O(1) memory, so n_rows=1_000_000 streams.

Shaped like a club's membership table, not like the original clubdata dump (which is not used):
- memid 0 is GUEST (recommendedby NULL). Real members are 1..n in join order, joindate increasing.
- Member k >= 2 was recommended by nobody with probability 0.35 (a walk-in: top of a new chain),
  otherwise by an earlier member j, chosen with a strong bias toward early members
  (j = 1 + floor((k-1) * r^2)). Early members, member 1 above all, build large subtrees; depth grows
  roughly logarithmically (max depth 5 at 300 rows, 18 at 1M rows for seed 1; the full closure
  has about 1.8 rows per member), far below MySQL's cte_max_recursion_depth (1000).
- Members 12 and 22 (the ones the query asks about) always have a recommender, so the result is
  never trivially empty; their chains are short because early members have few possible ancestors.
  The cost difference between the approaches comes from everyone ELSE's chains, which approach 1
  builds and approach 3 never touches.
- Recommenders always have smaller memids than the people they recommend (join order), so on this
  data "recommender DESC" equals "nearest first"; tests/edge_order.sql covers the case where it does not.
- First names / surnames come from small lists, so duplicate names are common (memid is the key).
"""
import datetime as dt
import random

FIRST = ["Avery", "Bea", "Cal", "Dina", "Eli", "Fay", "Gus", "Hana", "Ivo", "Jo", "Kai", "Lea",
         "Mo", "Nia", "Oren", "Pia", "Quin", "Rhea", "Sol", "Tove"]
LAST = ["Lin", "Okafor", "Duarte", "Petrov", "Novak", "Moreau", "Tanaka", "Ruiz", "Brandt", "Mensah",
        "Lund", "Sato", "Ilic", "Haddad", "Varga", "Nakamura"]
STREETS = ["Elm Row", "Oak Lane", "Pine Way", "Ash Court", "Birch Road", "Cedar St", "Fir Close"]
START = dt.datetime(2012, 1, 1, 8, 0, 0)
TARGETS = (12, 22)  # the members whose chains the query returns


def _members(n_rows: int, seed: int):
    rng = random.Random(f"{seed}-members")
    yield (0, "GUEST", "GUEST", "GUEST", 0, "(000) 000-0000", None, START)
    t = START
    for k in range(1, n_rows + 1):
        t += dt.timedelta(minutes=rng.randint(1, 600))
        if k == 1 or (k not in TARGETS and rng.random() < 0.35):
            rec = None
        else:
            rec = 1 + int((k - 1) * rng.random() ** 2)
        yield (k, rng.choice(LAST), rng.choice(FIRST),
               f"{rng.randint(1, 999)} {rng.choice(STREETS)}", rng.randint(10000, 99999),
               f"(555) {rng.randint(100, 999)}-{rng.randint(1000, 9999)}", rec, t)


def generate(n_rows: int, seed: int) -> dict:
    return {"members": _members(max(1, n_rows), seed)}
