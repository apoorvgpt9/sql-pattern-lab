"""Random data for Tree Node.

generate(n_rows, seed) -> {table: rows}; n_rows is the number of Tree rows (nodes).
Rows are yielded lazily with O(1) memory, so n_rows=1_000_000 streams.

The output is always a valid tree (one root, every p_id names an earlier node), shaped to exercise
the logic rather than to look tidy:
- Node k (k = 1..n in creation order) gets parent k-1 with ~25% probability (long chains: many
  single-child Inner nodes), a "hub" among the first ~1% of nodes with ~25% (a few parents with
  thousands of children: join fan-out), otherwise a uniformly random earlier node.
  Roughly half the nodes end up as leaves.
- ids are a pseudo-random permutation of creation order, ((k * MULT) mod P) for the prime
  P = 2^31 - 1, so an id says nothing about depth and children often have smaller ids than parents.
- Rows are emitted in creation order, i.e. not sorted by id.
"""
import random

P = 2_147_483_647  # prime; every id fits in a signed INT


def _id(k: int, mult: int) -> int:
    return (k * mult) % P  # bijective on 1..P-1 because P is prime and mult is not a multiple of P


def _tree(n_rows: int, seed: int):
    rng = random.Random(f"{seed}-tree")
    mult = rng.randrange(2, P - 1)
    n_hubs = max(1, n_rows // 100)
    for k in range(1, n_rows + 1):
        if k == 1:
            yield (_id(1, mult), None)
            continue
        r = rng.random()
        if r < 0.25:
            parent = k - 1
        elif r < 0.50:
            parent = rng.randint(1, min(n_hubs, k - 1))
        else:
            parent = rng.randint(1, k - 1)
        yield (_id(k, mult), _id(parent, mult))


def generate(n_rows: int, seed: int) -> dict:
    return {"Tree": _tree(max(1, n_rows), seed)}
