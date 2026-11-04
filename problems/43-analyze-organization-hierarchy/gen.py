"""Random data for Analyze Organization Hierarchy.

generate(n_rows, seed) -> {table: rows}; n_rows is the number of Employees rows.
Rows are yielded lazily. The only state is one byte per employee (their depth, used to set a
plausible salary), so n_rows=1_000_000 needs about 1 MB.

Shape (an org chart, not a random graph):
- Exactly one CEO (employee 1, manager_id NULL); the spec assumes a single CEO.
- Employee k >= 2 reports to an earlier employee j = 1 + floor((k-1) * r^1.6): early hires become
  managers of large subtrees, most later hires are individual contributors (about half the rows
  are leaves; seed 1: max depth 9 / average 4.3 at 300 rows, max 23 / average 9.4 at 1M rows),
  far below cte_max_recursion_depth (1000). The upward closure therefore has ~8.4M rows at 1M.
- Salary falls with depth (CEO highest), is rounded to 1,000 and drawn from a narrow band, so equal
  salaries - and equal budgets among leaves at the same level - are common: the name tie-break matters.
- employee_name comes from a short list, so duplicate names are common.
- employee_id is the hire order, so managers have smaller ids than their reports; no solution relies
  on that (tests/edge_order.sql inserts rows shuffled).
"""
import random
from array import array

FIRST = ["Ava", "Ben", "Cara", "Dev", "Eve", "Finn", "Gia", "Hal", "Ike", "Jun", "Kit", "Lou",
         "Mia", "Ned", "Ola", "Pat", "Quy", "Rex", "Sam", "Tia", "Uma", "Vik", "Wen", "Xan"]
DEPTS = ["Engineering", "Sales", "Support", "Finance", "Ops", "R&D", "Legal"]


def _employees(n_rows: int, seed: int):
    rng = random.Random(f"{seed}-org")
    depth = array("B", [0, 1])  # index = employee_id; depth[1] = 1 (CEO)
    for k in range(1, n_rows + 1):
        if k == 1:
            mgr, d = None, 1
        else:
            mgr = 1 + int((k - 1) * rng.random() ** 1.6)
            d = min(255, depth[mgr] + 1)
            depth.append(d)
        base = max(40, 300 - 35 * (d - 1))                # in thousands
        salary = 1000 * rng.randint(base - 10, base + 10)
        yield (k, rng.choice(FIRST), mgr, salary, rng.choice(DEPTS))


def generate(n_rows: int, seed: int) -> dict:
    return {"Employees": _employees(max(1, n_rows), seed)}
