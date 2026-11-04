"""Random data for Department Top Three Salaries.

Contract (harness/discovery.py): generate(n_rows, seed) returns {table_name: rows}, where rows is
a list or iterator of tuples in schema.sql column order. n_rows is the size of the main table.
Must be deterministic for a seed and stream (yield) rows so that n_rows=1_000_000 fits in memory.
"""
import random


def generate(n_rows: int, seed: int) -> dict:
    rng = random.Random(seed)
    raise NotImplementedError("write the generator")
