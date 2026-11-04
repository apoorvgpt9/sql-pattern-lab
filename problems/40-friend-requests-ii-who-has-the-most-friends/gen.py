"""Random data for Friend Requests II: Who Has the Most Friends.

generate(n_rows, seed) -> {table: rows}; n_rows is the number of RequestAccepted rows (exactly).
Rows are yielded lazily; memory is O(1) apart from one small sample per user.

The spec guarantees a single winner, so the data must too (otherwise LIMIT 1 is allowed to pick any
of the tied people and correct solutions could disagree). Construction:
- People are created one at a time (index u = 2, 3, ...). Each new person befriends a few distinct
  earlier people (1-6, skewed low), so every unordered pair is generated once, by its later endpoint:
  no duplicate pairs and no pair stored in both directions. Early people collect more friends (a
  long-tailed degree distribution, like real networks).
- Person index 1 is the "celebrity". The first HEAD rows are a pure star (celebrity + one new person
  each), and after that each new person also befriends the celebrity with probability 0.4. Their
  degree is then ~40% of all people, far above anyone else's (the others top out around
  avg_degree * ln(#people)). The winner is unique for every size the harness uses (checked for
  n_rows in 2..300 and seeds 1..10, plus spot checks up to 1M; n_rows=1 is one friendship, an
  unavoidable two-way tie, and the harness never asks for it).
- Direction is random: the later person is the requester or the accepter with equal odds, so the
  winner's friendships are split across both columns.
- ids are a pseudo-random permutation of the person index ((u * MULT) mod (2^31 - 1)), so the
  winner is neither the smallest nor the largest id.
- accept_date is random in 2023-2024 (irrelevant to the answer); ~2% NULL.
"""
import datetime as dt
import random

P = 2_147_483_647  # prime; ids fit in a signed INT
START = dt.date(2023, 1, 1)
HEAD = 8  # rows of pure star at the start


def _rows(n_rows: int, seed: int):
    rng = random.Random(f"{seed}-friends")
    mult = rng.randrange(2, P - 1)

    def pid(u: int) -> int:
        return (u * mult) % P

    emitted = 0

    def row(a: int, b: int):
        if rng.random() < 0.5:
            a, b = b, a
        d = None if rng.random() < 0.02 else START + dt.timedelta(days=rng.randrange(730))
        return (pid(a), pid(b), d)

    u = 1
    while emitted < n_rows:
        u += 1
        if u - 1 <= HEAD:                           # head start: pure star around the celebrity
            yield row(u, 1)
            emitted += 1
            continue
        if rng.random() < 0.4:                      # befriend the celebrity (person 1)
            yield row(u, 1)
            emitted += 1
            if emitted >= n_rows:
                return
        k = 1 + int(6 * rng.random() ** 2)          # 1..6 friends among persons 2..u-1 (u-2 >= HEAD)
        for v in rng.sample(range(2, u), k):
            yield row(u, v)
            emitted += 1
            if emitted >= n_rows:
                return


def generate(n_rows: int, seed: int) -> dict:
    return {"RequestAccepted": _rows(max(1, n_rows), seed)}
