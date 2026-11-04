"""Random data for Consecutive Numbers.

generate(n_rows, seed) -> {table: rows}; n_rows is the number of Logs rows.
Rows are yielded lazily so n_rows=1_000_000 streams without building lists.

Distributions chosen to exercise the logic:
- num comes from 40 string values ('1' .. '40') with a few "hot" values; each row repeats the previous value
  with probability 0.32 (otherwise a fresh draw), so runs of 1, 2, 3, 4, 5+ all occur. About 1 run in 10
  reaches length 3, so there are many qualifying runs but at most 40 distinct qualifying numbers: the
  DISTINCT step does a lot of de-duplication at large n_rows, and at n_rows=300 not every value qualifies.
- ids ascend, with roughly 2% of ids missing (deleted rows), so "adjacent in id order" differs from
  "id + 1" and the differential test compares solutions on that reading.
- No NULLs: the spec says nulls are not a case.
"""
import random

N_VALUES = 40
P_REPEAT = 0.32


def _logs(n_rows: int, seed: int):
    rng = random.Random(f"{seed}-logs")
    hot = [str(rng.randint(1, N_VALUES)) for _ in range(4)]
    prev, next_id = None, 0
    for _ in range(n_rows):
        next_id += 1
        while rng.random() < 0.02:   # a deleted row leaves a hole in the ids
            next_id += 1
        if prev is not None and rng.random() < P_REPEAT:
            num = prev
        elif rng.random() < 0.2:
            num = rng.choice(hot)
        else:
            num = str(rng.randint(1, N_VALUES))
        yield (next_id, num)
        prev = num


def generate(n_rows: int, seed: int) -> dict:
    return {"Logs": _logs(n_rows, seed)}
