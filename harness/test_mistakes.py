"""Optional mistakes/*.sql: tempting wrong queries. Each must FAIL every edge dataset it names.

This turns the README's "which naive approach this edge case breaks" claims into executed facts.
Header line in the file:  -- breaks: edge_a, edge_b
"""
import pytest

from harness.runner import check_edge
from harness.spec import BREAKS_RE


def test_mistake_is_caught(mysql_server, mistake_case):
    problem, mistake = mistake_case
    m = BREAKS_RE.search(mistake.read_text(encoding="utf-8"))
    assert m, f"{mistake} needs a '-- breaks: edge_x, edge_y' header line"
    named = [e.strip() for e in m.group(1).split(",") if e.strip()]
    unknown = sorted(set(named) - set(problem.edge_datasets()))
    assert not unknown, f"{mistake.name} names edge datasets that do not exist: {unknown}"
    still_pass = []
    for edge in named:
        try:
            check_edge(problem, edge, mistake)
        except AssertionError:
            continue  # caught, as claimed
        except Exception as exc:  # SQL error also counts as caught, but say so
            pytest.fail(f"{mistake.name} raised on {edge} instead of returning a wrong result: {exc}")
        still_pass.append(edge)
    assert not still_pass, f"{mistake.name} claims to break {still_pass} but passes them"
