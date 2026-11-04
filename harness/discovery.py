"""Find problems, edge datasets, solutions and gen.py modules on disk."""
from __future__ import annotations

import importlib.util
import re
import sys
from dataclasses import dataclass, field
from functools import cached_property
from pathlib import Path

import yaml

from .config import PROBLEMS_DIR, PROBLEMS_YAML

# Values of output.ordering that mean "compare as a multiset".
_UNORDERED = re.compile(r"^\s*(any(\s+order)?|single row|n/?a|none|unordered)\b", re.I)


def ordering_is_exact(ordering: str | None) -> bool:
    """meta.yaml output.ordering is free text; anything but 'any order'/'single row' is exact."""
    if ordering is None:
        return False
    return not _UNORDERED.match(str(ordering))


@dataclass
class Problem:
    path: Path
    meta: dict = field(repr=False)

    @property
    def name(self) -> str:
        return self.path.name

    @property
    def schema_sql(self) -> Path:
        return self.path / "schema.sql"

    @property
    def indexes_sql(self) -> Path | None:
        p = self.path / "indexes.sql"
        return p if p.exists() else None

    @property
    def my_answer(self) -> Path:
        return self.path / "my_answer.sql"

    @property
    def ordering(self) -> str | None:
        return (self.meta.get("output") or {}).get("ordering")

    @property
    def exact_order(self) -> bool:
        return ordering_is_exact(self.ordering)

    @property
    def output_columns(self) -> list[str]:
        return list((self.meta.get("output") or {}).get("columns") or [])

    def edge_datasets(self) -> list[str]:
        return sorted(p.stem for p in (self.path / "tests").glob("edge_*.sql"))

    def edge_sql(self, edge: str) -> Path:
        return self.path / "tests" / f"{edge}.sql"

    def expected_csv(self, edge: str) -> Path:
        return self.path / "expected" / f"{edge}.csv"

    def solutions(self) -> list[Path]:
        return sorted((self.path / "solutions").glob("*.sql"))

    def mistakes(self) -> list[Path]:
        return sorted((self.path / "mistakes").glob("*.sql"))

    @property
    def optimal(self) -> Path:
        """The reference solution: the highest-numbered file in solutions/."""
        sols = self.solutions()
        if not sols:
            raise LookupError(f"{self.name} has no solutions")
        return sols[-1]

    @cached_property
    def gen(self):
        """Import this problem's gen.py as an isolated module."""
        path = self.path / "gen.py"
        mod_name = f"spl_gen_{re.sub(r'[^0-9a-zA-Z_]', '_', self.name)}"
        spec = importlib.util.spec_from_file_location(mod_name, path)
        if spec is None or spec.loader is None:
            raise ImportError(f"cannot import {path}")
        module = importlib.util.module_from_spec(spec)
        sys.modules[mod_name] = module
        spec.loader.exec_module(module)
        if not callable(getattr(module, "generate", None)):
            raise AttributeError(f"{path} must define generate(n_rows: int, seed: int)")
        return module

    def generate(self, n_rows: int, seed: int) -> dict:
        data = self.gen.generate(n_rows=n_rows, seed=seed)
        if not isinstance(data, dict):
            raise TypeError(f"{self.name}/gen.py generate() must return dict[table, rows]")
        return data


def load_problem(path: Path) -> Problem:
    meta_path = path / "meta.yaml"
    meta = yaml.safe_load(meta_path.read_text(encoding="utf-8")) if meta_path.exists() else {}
    return Problem(path=path, meta=meta or {})


def all_problems(root: Path = PROBLEMS_DIR) -> list[Problem]:
    """Every problems/<dir>/ that has a meta.yaml."""
    if not root.exists():
        return []
    return [load_problem(p) for p in sorted(root.iterdir()) if (p / "meta.yaml").exists()]


def solved_problems(root: Path = PROBLEMS_DIR) -> list[Problem]:
    """Problems with at least one solutions/*.sql - the ones the correctness tests run."""
    return [p for p in all_problems(root) if p.solutions()]


def load_problems_yaml(path: Path = PROBLEMS_YAML) -> list[dict]:
    return yaml.safe_load(path.read_text(encoding="utf-8"))
