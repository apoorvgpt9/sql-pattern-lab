"""Random data for Last Person to Fit in the Bus.

generate(n_rows, seed) -> {table: rows}; n_rows is the number of people in the queue.
Rows are yielded lazily so n_rows=1_000_000 streams without building lists.

Distributions chosen to exercise the logic:
- Weights are positive integers: mostly 45-110, about 5% heavy (130-220). Only the first ~12 people can board,
  so the answer is always near the head of a very long queue.
- person_id is a permutation of the turn order (multiplicative bijection), so ordering by person_id gives
  the wrong answer; turns run 1..n with no gaps (spec).
- Rows are emitted in turn order. For seeds divisible by 3 the weight of the person at the capacity boundary is chosen so the running
  total lands exactly on 1000 (the "<=" boundary). Other seeds only land on 1000 by chance.
"""
import random

CAPACITY = 1000


def _next_prime(n: int) -> int:
    n += 1
    while True:
        if n > 1 and all(n % d for d in range(2, int(n ** 0.5) + 1)):
            return n
        n += 1


def _queue(n: int, seed: int):
    rng = random.Random(f"{seed}-queue")
    mult = _next_prime(max(n, 7) + seed)          # prime > n, so gcd(mult, n) = 1 and turn -> id is a bijection
    exact = seed % 3 == 0
    total = 0
    for turn in range(1, n + 1):
        w = rng.randint(130, 220) if rng.random() < 0.05 else rng.randint(45, 110)
        if exact and 800 <= total <= CAPACITY - 40 and CAPACITY - total <= 200:
            w = CAPACITY - total                  # makes the running total exactly 1000
        total += w
        person_id = ((turn - 1) * mult) % n + 1
        yield (person_id, f"P{person_id}", w, turn)


def generate(n_rows: int, seed: int) -> dict:
    return {"Queue": _queue(max(1, n_rows), seed)}
