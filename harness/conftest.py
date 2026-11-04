"""pytest wiring: parametrisation per (problem, edge dataset, solution) and the --mine flag."""
from __future__ import annotations

import pytest

from . import db
from .config import MySQLConfig
from .discovery import all_problems, solved_problems

MINE_MODULE = "test_mine.py"


def pytest_addoption(parser):
    parser.addoption(
        "--mine", action="store_true", default=False,
        help="run each problem's my_answer.sql against its edge datasets and the random "
             "differential check, instead of the reference tests (combine with -k <problem_dir>)",
    )


def _edge_params(problems, pick_solutions):
    params = []
    for p in problems:
        for edge in p.edge_datasets():
            for sol in pick_solutions(p):
                params.append(pytest.param((p, edge, sol), id=f"{p.name}/{edge}/{sol.stem}"))
    return params


def pytest_generate_tests(metafunc):
    names = metafunc.fixturenames
    if "edge_case" in names:
        metafunc.parametrize("edge_case", _edge_params(solved_problems(), lambda p: p.solutions()))
    if "edge_dataset" in names:
        metafunc.parametrize("edge_dataset", [
            pytest.param((p, e), id=f"{p.name}/{e}") for p in solved_problems() for e in p.edge_datasets()])
    if "solved_problem" in names:
        metafunc.parametrize("solved_problem", [pytest.param(p, id=p.name) for p in solved_problems()])
    if "any_problem" in names:
        metafunc.parametrize("any_problem", [pytest.param(p, id=p.name) for p in all_problems()])
    if "mistake_case" in names:
        metafunc.parametrize("mistake_case", [
            pytest.param((p, m), id=f"{p.name}/{m.stem}") for p in solved_problems() for m in p.mistakes()])
    if "mine_edge_case" in names:
        metafunc.parametrize("mine_edge_case", _edge_params(
            [p for p in all_problems() if p.my_answer.exists()], lambda p: [p.my_answer]))
    if "mine_problem" in names:
        metafunc.parametrize("mine_problem", [
            pytest.param(p, id=f"{p.name}/my_answer") for p in all_problems() if p.my_answer.exists()])


def pytest_collection_modifyitems(config, items):
    mine = config.getoption("--mine")
    keep, drop = [], []
    for item in items:
        is_mine = item.path.name == MINE_MODULE
        (keep if is_mine == mine else drop).append(item)
    if drop:
        config.hook.pytest_deselected(items=drop)
        items[:] = keep


@pytest.fixture(scope="session")
def mysql_server():
    """Fail fast (not skip) when MySQL is unreachable, so CI can never go green without it."""
    cfg = MySQLConfig.from_env()
    try:
        return db.wait_for_server(timeout_s=float(__import__("os").environ.get("MYSQL_WAIT_S", "10")), cfg=cfg)
    except RuntimeError as exc:
        pytest.fail(f"{exc}\nStart MySQL 8.0 (see README.md) or set MYSQL_HOST/MYSQL_PORT/MYSQL_USER/MYSQL_PASSWORD.",
                    pytrace=False)
